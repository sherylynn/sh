#/bin/bash
cd seafile-server-[0-9]* && \
  ./setup-seafile-mysql.sh auto -n sea -i 0.0.0.0 -p 8082 -d /home/haiwen/seafile-data/data \
  -e 0 -o db -t 3306 -r seafile -u seafile -w seafile -q seafile -c ccnet-db \
  -s seafile-db -b seahub-db
