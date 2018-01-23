docker build -t seafile .
docker run -itd --name seafile_db --restart=always -v /mnt/hgfs/seafile/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD="seafile" -e MYSQL_DATABASE="seafile" mysql
docker run -itd --name seafile_app --restart=always -v /mnt/hgfs/seafile/seafile-data:/home/haiwen/seafile-data --link seafile_db:db seafile /bin/bash