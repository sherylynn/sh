sudo mount /dev/sda2 /home/pi/mount-point/ -o uid=33 -o gid=0 -o umask=007 -o allow_other
docker exec cloud_app chown www-data:root /mount-point
