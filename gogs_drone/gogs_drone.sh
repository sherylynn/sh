#/bin/bash
#把gogs和drone都迁移到一起去
if [ ! -f "/usr/local/bin/drone" ]; then
    curl -L https://github.com/drone/drone-cli/releases/download/v0.8.0/drone_linux_amd64.tar.gz | tar zx
    sudo install -t /usr/local/bin drone
fi

if [ ! -f "/usr/local/bin/docker-compose" ]; then
    sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    sudo chmod 777 /usr/local/bin/docker-compose
fi
#如果存在就迁移
if [ -d "/etc/drone" ]; then
    #sudo /usr/local/bin/docker-compose -f /etc/drone/docker-compose.yml stop
    sudo systemctl stop drone.service
    sudo systemctl disable drone.service
    docker rm drone_drone-server_1
    docker rm drone_drone-agent_1
    sudo mv /etc/drone $HOME/drone
    sudo chown -R ${USER} $HOME/drone
    sudo chgrp -R ${USER} $HOME/drone
    rm docker-compose.yml
fi
if [ -d "$HOME/drone" ]; then
   mkdir $HOME/drone
fi
#如果配置文件不存在，则生成
if [ -f "$HOME/drone/drone.env" ]; then
tee $HOME/drone/drone.env <<-"EOF"
DRONE_HOST=http://111.231.90.43:3800/
DRONE_GOGS=true
DRONE_GOGS_URL=http://gogs:3000
DRONE_SECRET=""
EOF
  #如果已经有密钥就导入，如果没有就生成并存在.bashrc
  if [ $DRONE_SECRET ];then  
    sed -i '4c DRONE_SECRET='$DRONE_SECRET'' $HOME/drone/drone.env
  else
    DRONE_ENV_SECRET="$(LC_ALL=C </dev/urandom tr -dc A-Za-z0-9 | head -c 65)"
    sed -i '4c DRONE_SECRET='${DRONE_ENV_SECRET}'' $HOME/drone/drone.env
    echo export DRONE_SECRET=${DRONE_ENV_SECRET}|tee -a $HOME/.bashrc
  fi 

  if [ $DRONE_HOST ];then
    sed -i '1c DRONE_HOST='$DRONE_HOST'' $HOME/drone/drone.env
  else
    echo export DRONE_HOST=http://111.231.90.43:3800/|tee -a $HOME/.bashrc
  fi
fi
#统一修改gogs地址
sed -i '3c DRONE_GOGS_URL=http://gogs:3000' $HOME/drone/drone.env
#if [ $DRONE_GOGS_URL ];then
#  sed -i '3c DRONE_GOGS_URL='$DRONE_GOGS_URL'' $HOME/drone/drone.env
#else
#  echo export DRONE_GOGS_URL=gogs:3000|tee -a $HOME/.bashrc
#fi 

sudo ln -sf ~/sh/gogs_drone/gogs_drone.yml $HOME/drone/
#关停原来的gogs服务
docker stop gogs
docker rm gogs
#拉起新服务
docker-compose -f $HOME/drone/gogs_drone.yml up --force-recreate
#删除容器
#docker-compose down 