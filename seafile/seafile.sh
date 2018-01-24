#/bin/bash
docker run -itd --name seafile_db --restart=always -v /mnt/hgfs/seafile/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD="seafile" -e MYSQL_DATABASE="seafile" mysql
docker run -itd --name seafile_app --restart=always -p 8000:8000 -p 8082:8082 \
  -v /mnt/hgfs/seafile/seafile-data:/home/haiwen/seafile-data \
  --link seafile_db:db seafile /bin/bash
#第一次初始化用上面的进 seafile-server-* 运行 setup-mysql 然后把后面的文件拷贝下来
#不然初始化时傻逼检测会说已经存在
#或许下次直接从构建文件的时候就引入进去
docker run -itd --name seafile_app --restart=always -p 8000:8000 -p 8082:8082 \
  -v /mnt/hgfs/seafile/seafile-data:/home/haiwen/seafile-data \
  -v /mnt/hgfs/seafile/ccnet:/home/haiwen/ccnet \
  -v /mnt/hgfs/seafile/conf:/home/haiwen/conf \
  -v /mnt/hgfs/seafile/seahub-data:/home/haiwen/seahub-data \
  --link seafile_db:db seafile /bin/bash
#docker run -itd --name seafile_app --restart=always -p 8000:8000 -p 8082:8082 -v /mnt/hgfs/seafile/haiwen:/home/haiwen --link seafile_db:db seafile /bin/bash