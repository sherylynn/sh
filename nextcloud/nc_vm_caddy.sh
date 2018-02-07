#/bin/bash
docker run -itd --name cloud_db --restart=always -v /mnt/hgfs/nextcloud/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD="nextcloud" -e MYSQL_DATABASE="nextcloud" mysql
docker run -itd --name cloud_app --restart=always -p 9000:9000 \
  -v /mnt/hgfs/nextcloud/html:/var/www/html \
  --link cloud_db:db nextcloud:fpm