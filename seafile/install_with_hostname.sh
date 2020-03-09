#!/bin/bash
hostname=$1
help_message="add your hostname as args"
greeting_message="now start process"
case $hostname in
  "")echo $help_message && exit;;
  *)echo "$greeting_message\nyour hostname is $hostname" ;;
esac

#copy configure
cp ./Caddyfile_docker_pdf ./Caddyfile_docker_hostname
cp ./docker-compose_caddy_pdf.yml ./docker-compose_caddy_hostname.yml

# change hostname
vi ./Caddyfile_docker_hostname -c ":%s/pdf.sherylynn.win/$hostname/g" -c ":wq!"

vi ./docker-compose_caddy_hostname.yml -c ":%s/pdf.sherylynn.win/$hostname/g" -c ":wq!"

# link to new caddyfile
vi ./docker-compose_caddy_hostname.yml -c ":%s/Caddyfile_docker_pdf/Caddyfile_docker_hostname/g" -c ":wq!"

# change first /root to $HOME ,not all

vi ./docker-compose_caddy_hostname.yml -c ":%s#/root#$HOME" -c ":wq!"

server_start(){
  # start server
  docker-compose -f ./docker-compose_caddy_hostname.yml up -d
}

server_stop(){
  # stop server if server is running
  docker-compose -f ./docker-compose_caddy_hostname.yml down
}

server_restart(){
  if [[ "$(docker ps -a |grep seafile)" == *"seafile"* ]] ;then
    echo $(server_stop )
    echo $(server_start )
  else
    echo $(server_start )
  fi
  echo "server finish"
}
read -p "should we restart server ? y or n : " RESTART
case $RESTART in
  y) echo $(server_restart) ;;
  n) echo "enjoying" ;;
esac
