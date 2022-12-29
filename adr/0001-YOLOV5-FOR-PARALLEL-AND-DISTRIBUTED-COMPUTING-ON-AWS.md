# PROPOSAL: Implementing YOLOv5 on AWS for Parallel and Distributed Computing

## Status
Proposed by: Yu Yuen Hern (30 Dec 2022)

Updated by: <NAME> <DATE>

## Context
We want to implement a parallel and distributed YOLOv5 system on AWS, to perform object detection (inference). Given 1000 images, we want to:
1. Perform object detection on the images using YOLOv5
2. Compare inferencing performance for single compute vs parallel compute.

Note: Any object detection dataset is fine.

## Proposed Approach
Based on this [tutorial](https://docs.ultralytics.com/environments/AWS-Quickstart/), we want to implement:
1. HT Condor for job scheduling
2. Network File System (NFS) for distributed file system
3. Python and PyTorch to perform inference on executor machines
4. (Optional) A simple Streamlit frontend for non-coder users

Note: Only CPU will be used.

### Implementation Procedure
1. Create four (4) EC2 instances
    - Need to find out if AWS Deep Learning Amazon Machine Image is required
    - Choose larger storage for Central Manager
2. Implement HT Condor in all instances
    - Set up one (1) Central Manager, one (1) Submission Host and two (2) 2-core Executors
3. Implement NFS in all instances
    - Main file system will be on Central Manager
4. Set up core dependencies on Executors
    - Install [Python 3.10.5](https://serverspace.io/support/help/install-python-latest-version-on-ubuntu-20-04/) **(Check if DLAMI helps with this)**
    - Fork this [repo](https://github.com/yuenherny/um-wqd7008-pdc-yolov5)
    - Create virtual environment and install dependencies in `requirements.txt`
    - Activate environment and run `detect.py` with `yolo5s` for the first time

### UX Approach 1
A script that:
    - Upload images into NFS main file system
    - Performs inference on the images via NFS
    - Saves the files in main file system via NFS
    - Downloads the final images as a zip file

### UX Approach 2
A Streamlit frontend that does the same thing as in UX Approach 1

## Consequences

### Using Approach 1
Advantages: Easier implementation, not time consuming

Disadvantages: Not friendly to non-coder especially those not familiar with Linux

### Using Approach 2
Advantages: Friendly to non-coder, better demo experience

Disadvantages: Time consuming, slightly challenging implementation

## Discussion
TBD