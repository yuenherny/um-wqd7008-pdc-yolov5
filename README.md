# Implementing YOLOv5 for Parallel and Distributed Computing (AWS)

This repo is forked and modified from [Ultralytics's YOLOv5 Pytorch implementation](https://github.com/ultralytics/yolov5). Visit here for the original [README](https://github.com/ultralytics/yolov5#readme).

## Table of Content
1. [Project structure](#project-structure)
2. [How to use](#how-to-use)
    - [AWS Setup](#amazon-web-services-aws-setup)
    - [HTCondor Setup](#htcondor-setup)
    - [NFS Setup](#network-file-system-nfs-setup)
    - [YOLO Setup](#you-only-look-once-yolo-model-inference-setup)
    - [Gdrive Setup](#google-drive-setup)
3. [Putting everything together: DAGMan Workflow](#putting-everything-together-htcondor-workflow-execution-using-dagman)
4. [Common Issues](#common-issues)

## Project structure
The project is structured as follows:
```
<root>
|-- adr (architectural decision records)
|-- archive
|-- classify (classification)
|-- data
|   |-- hyps (hyperparam YAMLs)
|   |   |-- hyp.*.yaml
|   |   |-- ...
|   |
|   |-- images (images folder)
|   |-- scripts (bash scripts folder)
|   |-- pricetag.yaml (dataset config for this project)
|   |-- *.yaml (configs for other datasets)
|
|-- models (model configs)
|   |-- hub
|   |-- segment
|   |-- *.py
|   |-- yolov5*.yaml (YOLOv5 configs)
|
|-- runs
|   |-- detect
|   |   |-- exp* (folder containing detection results)
|
|-- segment (Python files for segmentation)
|-- utils (utility functions)
|-- detect.py (run this to perform inference)
|-- train.py (run this to train your model)
|-- *.py (other Python files)
|-- requirements.txt
```
Note: Some files are omitted in the project tree above for the sake of brevity.

## How to use
This section outlines the step-by-step procedure to replicate this project.

### Amazon Web Services (AWS) Setup
1. Spin up EC2 instances with **Ubuntu AMI 20.04**. Configure them as follows:
    - Instance 1:
        - Name: **YOLO-CentralMgt**
        - Type: t2.micro
    - Instance 2:
        - Name: **YOLO-SubmHost**
        - Type: t2.micro
    - Instance 3:
        - Name: **YOLO-Executor**
        - Type: t2.micro (Can be upgraded to t2.large if needed)
    - **Group all instances into single security group, and private key pair `.pem` is used to login in this project.**
2. Access the instances via terminal by using the command at the `Connect` button at each instances.
    ```
    $ cd .ssh
    $ ssh -i "private_key.pem" ubuntu@ec2-11-111-11-111.compute-1.amazonaws.com
    ```

### HTCondor Setup
1. Install HTCondor in all three (3) instances.
    - Perform update on all instances via `sudo apt-get update` on all instances.
    - Install HTCondor using this [guide](https://htcondor.readthedocs.io/en/latest/getting-htcondor/admin-quick-start.html#assigning-roles-to-machines) on respective machines as follows (Note that the variables marked `$` should be replaced with user-defined values):
        - YOLO-CentralMgt: 
        ```
        $ curl -fsSL https://get.htcondor.org | sudo GET_HTCONDOR_PASSWORD="$htcondor_password" /bin/bash -s -- --no-dry-run --central-manager $central_manager_name
        ```
        - YOLO-SubmHost:
        ```
        $ curl -fsSL https://get.htcondor.org | sudo GET_HTCONDOR_PASSWORD="$htcondor_password" /bin/bash -s -- --no-dry-run --submit $central_manager_name
        ```
        - YOLO-Executor:
        ```
        $ curl -fsSL https://get.htcondor.org | sudo GET_HTCONDOR_PASSWORD="$htcondor_password" /bin/bash -s -- --no-dry-run --execute $central_manager_name
        ```
        - At YOLO-SubmHost, run `$ condor_status` to see execute machines in the pool, `$ condor_submit` to submit jobs and `$ condor_q` to see the jobs run.
2. At each instance, update `/etc/hosts` with IP address and machine names.
    ```
    $ sudo nano /etc/hosts
    ```
    Add the CentralMgt, SubmHost and Executor IP address and machine name like below:
    ```
    127.0.0.1 localhost
    172.31.92.114 CentralMgt
    172.31.91.11 SubmHost
    172.31.88.90 Executor

    # The following lines are desirable for IPv6 capable hosts
    ::1 ip6-localhost ip6-loopback
    ...
    ```
3. Edit inbound rules for security group to allow all traffic to pass within the pool group.
    - At sidebar, go to **Network & Security** and select **Security Groups**.
    - Choose the security group that applies to the pool.
    - At **Inbound rules**, select **Edit inbound rules**, then **Add rule**.
    - Choose `All traffic` for **Type**, `Custom` for **Source**, and select the security group in the box next to **Source**. Then **Save rules**.
    - Test HTCondor using this `sleep.sh` [example](https://htcondor.readthedocs.io/en/latest/users-manual/quick-start-guide.html#a-first-htcondor-job).

### Network File System (NFS) Setup
The following setup procedure can be found [here](https://ubuntu.com/server/docs/service-nfs).
1.  Install NFS Server on SubmHost, and then start it.
    ```
    $ sudo apt install nfs-kernel-server
    $ sudo systemctl start nfs-kernel-server.service
    ```
2. Create `yolo` folder at `/home/ubuntu` in SubmHost and Executor instances.
    ```
    $ mkdir /yolo
    ```
3. Add the `yolo` folder to `/etc/exports` file.
    ```
    $ sudo nano /etc/exports
    ```
    Add `/home/ubuntu/yolo *(rw,sync,no_subtree_check)` into the file like below:
    ```
    # /etc/exports: the access control list for filesystems which may be exported
    #               to NFS clients.  See exports(5).
   ...
    #
    /home/ubuntu/yolo *(rw,sync,no_subtree_check)
    ```
    Then apply the new config via
    ```
    $ sudo exportfs -a
    ```
4. At Executor instance, install NFS Client and then start it if it is not active.
    ```
    $ sudo apt install nfs-common
    $ sudo systemctl status nfs-common.service
    $ sudo systemctl start nfs-common.service
    ```
5. Still at Executor, mount the created `/home/ubuntu/yolo` directory to the exported directory in NFS Server.
    ```
    $ sudo mount SubmHost:/home/ubuntu/yolo /home/ubuntu/yolo
    ```
    Test by creating a file at SubmHost and echo its content in the Executor side.
    ```
    # At SubmHost
    $ cd /home/ubuntu/yolo
    $ echo "Hello" > testfile.txt

    # At Executor
    $ cd /home/ubuntu/yolo
    $ echo testfile.txt
    ```
See [Common Issues](#common-issues) if you run into any issues during NFS setup.

### You Only Look Once (YOLO) Model Inference Setup
1. Clone this [repository](https://github.com/yuenherny/um-wqd7008-pdc-yolov5) to Executor because there are several Ubuntu-based packages needed to run YOLO model. Note that Git and Python 3.8 come pre-installed with Ubuntu 20.04 AMI.
    ```
    $ git clone https://github.com/yuenherny/um-wqd7008-pdc-yolov5.git
    ```
2. Install required Ubuntu packages for **OpenCV** and **venv**.
    ```
    $ sudo apt install python3-opencv
    $ sudo apt install python3.8-venv
    ```
3. At the cloned local repository, create and activate Python environment.
    ```
    $ cd um-wqd7008-pdc-yolov5
    $ python3 -m venv venv
    $ source venv/bin/activate
    ```
    Check if environment is activated. You should see a list of pre-installed packages.
    ```
    $ pip list
    ```
4. Before installing other dependencies using `requirements.txt`, install **torch** and **torchvision** packages from the [official PyTorch docs](https://pytorch.org/get-started/locally/), as downloads via PyPi wheel can be slow on AWS.
    - At **START LOCALLY** section, choose:
        - PyTorch Build: Stable
        - Your OS: Linux
        - Package: Pip
        - Language: Python
        - Compute Platform: CPU
    - Then copy the command with **torchaudio** removed.
    ```
    $ pip3 install torch torchvision --extra-index-url https://download.pytorch.org/whl/cpu
    ```
5. Amend `requirements.txt` and comment out `thop>=0.1.1`, then save.
    ```
    $ nano requirements.txt
    ```
    Then, install dependencies.
    ```
    $ pip install -r requirements.txt
    ```
6. Now that required dependencies are installed, we can check if things could be run like normal - invoking from terminal.
    ```
    $ python3 detect.py --weights yolov5s.pt --source data/images/zidane.jpg
    ```
    This would download the YOLOv5s weights and perform inference using `data/images/zidane.jpg` input source. You should see something like below:
    ```
    detect: weights=['yolov5s.pt'], source=data/images/bus.jpg, data=data/coco128.yaml, imgsz=[640, 640], conf_thres=0.25, iou_thres=0.45, max_det=1000, device=, view_img=False, save_txt=False, save_conf=False, save_crop=False, nosave=False, classes=None, agnostic_nms=False, augment=False, visualize=False, update=False, project=runs/detect, name=exp, exist_ok=False, line_thickness=3, hide_labels=False, hide_conf=False, half=False, dnn=False, vid_stride=1

    Fusing layers...
    YOLOv5s summary: 213 layers, 7225885 parameters, 0 gradients
    image 1/1 /home/ubuntu/yolo/um-wqd7008-pdc-yolov5/data/images/bus.jpg: 640x480 4 persons, 1 bus, 309.3ms
    Speed: 2.9ms pre-process, 309.3ms inference, 3.7ms NMS per image at shape (1, 3, 640, 640)
    Results saved to runs/detect/exp
    ```
    which means inference is successful and the result is saved to **runs/detect/exp** folder.

### Submit a HTCondor Job to Perform Inference
1. At SubmHost, create a bash file (see `yolo.sh`).
    ```
    $ nano yolo.sh
    ```
    Then paste this into the bash file, and save:
    ```
    #!/usr/bin/bash
    # file name: yolo.sh

    # check python version
    echo "$(python3 --version)"

    # change to directory
    cd /home/ubuntu/yolo/um-wqd7008-pdc-yolov5
    echo "Directory changed"

    # activate python env
    source venv/bin/activate
    echo "Python env activated"

    # run detect.py on an image
    echo "Execution start"
    python3 detect.py --weights yolov5s.pt --source data/images/bus.jpg
    echo "Execution complete"

    # deactivate python env
    deactivate
    echo "Python env deactivated"
    ```
    Without the shebang (the first line in bash file - `#!/usr/bin/bash`), you might get the following error:
    ```
    ...
    007 (019.000.000) 2023-01-09 10:23:53 Shadow exception!
            Error from slot1@ip-172-31-88-90.ec2.internal: Failed to execute '/var/lib/condor/execute/dir_1257/condor_exec.exe': (errno=8: 'Exec format error')
            0  -  Run Bytes Sent By Job
            298  -  Run Bytes Received By Job
    ...
    012 (019.000.000) 2023-01-09 10:23:53 Job was held.
            Error from slot1@ip-172-31-88-90.ec2.internal: Failed to execute '/var/lib/condor/execute/dir_1257/condor_exec.exe': (errno=8: 'Exec format error')
            Code 6 Subcode 8
    ...
    ```
    This shebang-induced error is documented [here](https://git.scc.kit.edu/sdil/faq/-/issues/34) and [here](https://stackoverflow.com/questions/44813117/htcondor-shadow-exception-errno-8-exec-format-error/75058436).
2. Still at SubmHost, create a HTCondor submit file (see `yolo.sub`).
    ```
    $ nano yolo.sub
    ```
    Then paste the following into it, and save:
    ```
    # YOLO detection on an image

    executable   = yolo.sh

    output       = yolo.out
    error        = yolo.err
    log          = yolo.log

    should_transfer_files = yes
    when_to_transfer_output = ON_EXIT

    queue
    ```
3. Still at SubmHost, submit `yolo.sh` as a job using `yolo.sub` submit file.
    ```
    $ condor_submit yolo.sub
    ```
If there were no errors, you should see your result in the Executor instance's `um-wqd7008-pdc-yolov5/runs/detect/exp` directory. However, you might get the following output in `yolo.err`:
```
Traceback (most recent call last):
File "detect.py", line 261, in <module>
    main(opt)
File "detect.py", line 256, in main
    run(**vars(opt))
File "/home/ubuntu/yolo/um-wqd7008-pdc-yolov5/venv/lib/python3.8/site-packages/torch/autograd/grad_mode.py", line 27, in decorate_context
    return func(*args, **kwargs)
File "detect.py", line 98, in run
    model = DetectMultiBackend(weights, device=device, dnn=dnn, data=data, fp16=half)
File "/home/ubuntu/yolo/um-wqd7008-pdc-yolov5/models/common.py", line 345, in __init__
    model = attempt_load(weights if isinstance(weights, list) else w, device=device, inplace=True, fuse=fuse)
File "/home/ubuntu/yolo/um-wqd7008-pdc-yolov5/models/experimental.py", line 79, in attempt_load
    ckpt = torch.load(attempt_download(w), map_location='cpu')  # load
File "/home/ubuntu/yolo/um-wqd7008-pdc-yolov5/venv/lib/python3.8/site-packages/torch/serialization.py", line 771, in load
    with _open_file_like(f, 'rb') as opened_file:
File "/home/ubuntu/yolo/um-wqd7008-pdc-yolov5/venv/lib/python3.8/site-packages/torch/serialization.py", line 270, in _open_file_like
    return _open_file(name_or_buffer, mode)
File "/home/ubuntu/yolo/um-wqd7008-pdc-yolov5/venv/lib/python3.8/site-packages/torch/serialization.py", line 251, in __init__
    super(_open_file, self).__init__(open(name, mode))
PermissionError: [Errno 13] Permission denied: 'yolov5s.pt'
```
or:
```
Traceback (most recent call last):
  File "detect.py", line 261, in <module>
    main(opt)
  File "detect.py", line 256, in main
    run(**vars(opt))
  File "/home/ubuntu/yolo/um-wqd7008-pdc-yolov5/venv/lib/python3.8/site-packages/torch/autograd/grad_mode.py", line 27, in decorate_context
    return func(*args, **kwargs)
  File "detect.py", line 94, in run
    (save_dir / 'labels' if save_txt else save_dir).mkdir(parents=True, exist_ok=True)  # make dir
  File "/usr/lib/python3.8/pathlib.py", line 1288, in mkdir
    self._accessor.mkdir(self, mode)
PermissionError: [Errno 13] Permission denied: 'runs/detect/exp2'
```
The `[Errno 13]` error means that the program tried to create new file or folder but it was denied due to write permission issues. We need to assign other users with write access permissions in both project root and the `runs/detect/` directory. At the parent directory of `um-wqd7008-pdc-yolov5`:
```
$ chmod 777 um-wqd7008-pdc-yolov5
$ chmod 777 um-wqd7008-pdc-yolov5/runs
```
Change permissions for other files and directories if needed. Read more about `chmod` [here](https://www.pluralsight.com/blog/it-ops/linux-file-permissions).

### Google Drive Setup
To support uploading to Google Drive, we will be using [gdrive](https://github.com/glotlabs/gdrive).

Before proceeding, please create Google OAuth Client credentials by following this [guide](https://github.com/glotlabs/gdrive/blob/main/docs/create_google_api_credentials.md).

Due to a limitation of this package which requires a web browser, you are required to perform this setup on a GUI-supported local machine. After the setup, we will then export the account and import it on any remote server.

#### Part 1: Setup on Local Machine

1.  Download the [latest release ](https://github.com/glotlabs/gdrive/releases)from Github. `v3.1.0` as of Jan 10, 2023.
2.  Unzip the Archive
3.  Open Terminal where gdrive is located, add Google Account to gdrive
    ```
    $ ./gdrive account add
    ```
    - This will prompt you for your google Client ID and Client Secret
    - Next you will be presented with an url
    - Open the url in your browser and give approval for gdrive to access your Google Drive
    - You will be redirected to `http://localhost:8085` (gdrive starts a temporary web server) which completes the setup
    - Gdrive is now ready to use!

4.  Test upload a file
    ```
    $ ./gdrive files upload <FILE_PATH>
    ```
5.  Export your gdrive Account (i.e. student_id@siswa.um.edu.my)
    ```
    $ ./gdrive account export <ACCOUNT_NAME>
    ```
6. Copy the exported archive to the remote server(s) using the command below:
    ```
    $ scp <Options> <PATH/ON/LOCAL> <SERVER_NAME>@<HOST>:<PATH/ON/SERVER>
    ```
    Example:
    ```
    $ scp -i "nicholasleezt-7008.pem" ~/Downloads/gdrive_export-s2132376_siswa_um_edu_my.tar ubuntu@ec2-18-234-241-246.compute-1.amazonaws.com:/home/ubuntu
    ```

#### Part 2: On Remote Server(s)
1.  Download the latest release from Github. `v3.1.0` as of Jan 10, 2023.
    ```
    $ wget https://github.com/glotlabs/gdrive/releases/download/3.1.0/gdrive_linux-x64.tar.gz
    ```
2.  Unzip the archive.
    ```
    $ tar -xvf gdrive_linux-x64.tar.gz
    ```
3. Put the gdrive binary at your PATH (i.e. `/usr/local/bin`)
    ```
    $ sudo mv /home/ubuntu/gdrive /usr/local/bin
    ```
4. Import the gdrive account.
    ```
    $ gdrive account import <EXPORTED_ACCOUNT>
    ```
5.  Test upload a file.
    ```
    $ gdrive files upload <FILE/TO/PATH>
    ```
6. Alternatively, to upload to a specific folder in your gdrive, run:
   ```
   $ gdrive files list
   ```
   to get the folder ID. You will see something like:
   ```
    Id                                                                          Name                                      Type       Size       Created
    1N6Hs1Tx1f0ubfKphI4cfGyZCGsjJCEz4                                           Folder1                                    folder                2022-12-31 09:24:37
    1i7uFBCbqgw176TftRsws6z0BTr64zB1m                                           Folder2                                folder                2022-11-07 06:43:56
    1GNCqI5lG-6wd_XQnYz0Z1z3ReUTGUQUY                                           Folder3                             folder                2022-07-20 12:48:50
   ```
   then do:
   ```
   $ gdrive files upload <PATH/TO/FILE> --parent <FOLDER_ID>
   ```
   Note that as of 15 Jan 2023, gdrive package is only able to upload files. Folders or multiple files are not supported.

## Putting Everything Together: HTCondor Workflow Execution using DAGMan
The DAGMan workflow [yolo-gdrive.dag](yolo-gdrive.dag) aims to:
1. Perform YOLO inference on images on parallel - see [yolo.sh](yolo.sh) and [yolo.sub](yolo.sub)
2. Upload the results to a Google Drive folder - see [gdrive.sh](gdrive.sh) and [gdrive.sub](gdrive.sub)

Unfortunately, the shell script for gdrive execution was unable to complete due to permission issues:
```
Error: Failed to create directory '/nonexistent/.config/gdrive3': Permission denied (os error 13)
Error: No account has been selected
Use `gdrive account list` to show all accounts.
Use `gdrive account switch` to select an account.
...
Error: No account has been selected
Use `gdrive account list` to show all accounts.
Use `gdrive account switch` to select an account.
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
```

## Common Issues

### Issue 1: NFS Client (on Executor instance) inactive after instance stopped and started
This could happen when you stopped and then started the instance after complete setting up NFS Server and Client (you took a break and resumed this project).

**Solution: Start the NFS Client service on Executor.**
1. At Executor, start the NFS Client:
    ```
    $ sudo systemctl start nfs-common.service
    ```
2. At Executor, perform mounting:
    ```
    $ sudo mount <NFS_SERVER_IP_ADDRESS_OR_MACHINE_NAME>:<DIR_ON_NFS_SERVER> <DIR_ON_NFS_CLIENT>
    ```

### Issue 2: NFS Client could not be started due to masked
This could happen when your NFS Client service unit file was symlinked to `/dev/null`.

**Solution: Remove the symlink, unmask and start the service.**
1. At Executor, navigate to `/lib/systemd/system/` and check if service unit file was symlinked to `/dev/null`.
    ```
    $ file /lib/systemd/system/nfs-common.service
    OR
    $ file /etc/systemd/system/nfs-common.service
    ```
    It should return:
    ```
    /lib/systemd/system/nfs-common.service: symbolic link to /dev/null
    ```
2. Delete the symlink.
    ```
    $ sudo rm /lib/systemd/system/nfs-common.service
    ```
3. Reload the systemd daemon:
    ```
    $ sudo systemctl daemon-reload
    ```
4. Unmask, start and check the service:
    ```
    $ sudo systemctl unmask nfs-common.service
    $ sudo systemctl start nfs-common.service
    $ $ sudo systemctl status nfs-common.service
    ```
As documented [here](https://unix.stackexchange.com/questions/308904/systemd-how-to-unmask-a-service-whose-unit-file-is-empty) and [here](https://www.suse.com/support/kb/doc/?id=000019136).