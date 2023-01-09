# Implementing YOLOv5 for Parallel and Distributed Computing (AWS)

This repo is forked and modified from [Ultralytics's YOLOv5 Pytorch implementation](https://github.com/ultralytics/yolov5). Visit here for the original [README](https://github.com/ultralytics/yolov5#readme).

## Table of Content
1. [Project structure](#project-structure)
2. [How to use](#how-to-use)

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
