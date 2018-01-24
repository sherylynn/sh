docker build -t seafile .
docker run -itd --name seafile_db --restart=always -v /mnt/hgfs/seafile/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD="seafile" -e MYSQL_DATABASE="seafile" mysql
#docker run -itd --name seafile_app --restart=always -p 8000:8000 -p 8082:8082 -v /mnt/hgfs/seafile/seafile-data:/home/haiwen/seafile-data --link seafile_db:db seafile /bin/bash
docker run -itd --name seafile_app --restart=always -p 8000:8000 -p 8082:8082 -v /mnt/hgfs/seafile/haiwen:/home/haiwen --link seafile_db:db seafile /bin/bash