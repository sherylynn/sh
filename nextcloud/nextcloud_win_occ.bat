docker run -itd --name cloud_db --restart=always -v F:/nextcloud/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD="nextcloud" -e MYSQL_DATABASE="nextcloud" mysql
docker run -itd --name occ --restart=always -v F:/nextcloud/nextcloud:/var/www/html -v F:/nextcloud/nextcloud:/usr/src/nextcloud --link cloud_db:db nextcloud /bin/bash

::如果全部清空 就全部扫描,并输出进展情况(为了缓解焦虑)
::php /var/www/html/occ files:cleanup 
::php /var/www/html/occ files:scan --all --verbose

::如果只添加部分
::php /var/www/html/occ files:scan --path='/sherylynn/files/photoslibrary'
::su - www-data -s /bin/bash -c "php /var/www/html/occ files:scan --path='/sherylynn/files/photoslibrary'"