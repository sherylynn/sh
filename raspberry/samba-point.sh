sudo mount -t cifs -o uid=33,gid=0,file_mode=007,dir_mode=007,username=${samba_user},password=${samba_password} //${samba_ip}/share /home/pi/samba-point
#sudo mount -t cifs -o uid=33,gid=0,file_mode=0777,dir_mode=0777,username=${samba_user},password=${samba_password} //${samba_ip}/share /home/pi/samba-point
docker exec cloud_app chown www-data:root /samba-point
