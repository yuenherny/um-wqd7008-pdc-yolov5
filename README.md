# Implementing YOLOv5 for Parallel and Distributed Computing (AWS)

This repo is forked and modified from [Ultralytics's YOLOv5 Pytorch implementation](https://github.com/ultralytics/yolov5). Visit here for the original [README](https://github.com/ultralytics/yolov5#readme) and [Training Custom Data tutorial](https://github.com/ultralytics/yolov5/wiki/Train-Custom-Data).

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
TBD
