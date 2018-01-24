docker run -itd --name seafile_db --restart=always -p 3306:3306 -v /mnt/hgfs/seafile/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD="seafile" -e MYSQL_DATABASE="seafile" mysql
sudo ./seafile_install.sh