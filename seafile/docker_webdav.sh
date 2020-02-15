#/bin/bash
configureFile=~/seafile_drive/seafile-data/seafile/conf/seafdav.conf
sed -i 's/enabled = false/enabled = true/g' $configureFile
WEBDAV='share_name = webdav'
sed -i 's/fastcgi = false/fastcgi = true/g' $configureFile
sed -i '/share_name/c share_name = \/webdav' $configureFile
