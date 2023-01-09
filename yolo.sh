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
