#/bin/bash

sed -i 's/127.0.0.1/0.0.0.0/g' conf/gunicorn.conf.py 
