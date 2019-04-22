#sudo apt install davfs2
sudo mount -t davfs https://pi.sherylynn.win/remote.php/webdav /home/lynn/webdav-point
#davfs does support username or password option
#sudo mount -t davfs -o uid=33,gid=0,file_mode=007,dir_mode=007,username=${webdav_user},password=${webdav_password} ${webdav_url} /home/pi/webdav-point
docker exec cloud_app chown www-data:root /webdav-point
