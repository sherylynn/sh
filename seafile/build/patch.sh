#/bin/bash

sed -i 's/127.0.0.1/0.0.0.0/g' conf/gunicorn.conf.py 
sed -i 's/enabled = false/enabled = true/g' conf/seafdav.conf
WEBDAV='share_name = webdav'
#sed -i "/share_name/c $webdav" conf/seafdav.conf 
sed -i '/share_name/c share_name = \/webdav' conf/seafdav.conf 
