#/bin/bash
docker run -itd --name cloud_db --restart=always \
  -v /mnt/hgfs/nextcloud/mysql:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD="nextcloud" \
  -e MYSQL_DATABASE="nextcloud" \
  mysql
docker run -itd --name occ --restart=always \
  -v /mnt/hgfs/nextcloud/nextcloud:/var/www/html \
  -v /mnt/hgfs/nextcloud/nextcloud:/usr/src/nextcloud \
  --link cloud_db:db \
  nextcloud /bin/bash

#php /var/www/html/occ files:scan --path='/sherylynn/files/photoslibrary'
#su - www-data -s /bin/bash -c "php /var/www/html/occ files:scan --path='/sherylynn/files/photoslibrary'"
  