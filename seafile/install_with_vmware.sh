#!/bin/zsh
vmware_folder=/mnt/seafile
hostname=$1
help_message="add your hostname as args"
greeting_message="now start process"
case $hostname in
  "")echo $help_message && exit;;
  *)echo "$greeting_message\nyour hostname is $hostname" ;;
esac

#copy configure
cp ./docker-compose_vm_pdf.yml ./docker-compose_vm_hostname.yml

# change hostname

vi ./docker-compose_vm_hostname.yml -c ":%s/pdf.sherylynn.win/$hostname/g" -c ":wq!"

# link to new vmfile
vi ./docker-compose_vm_hostname.yml -c ":%s/vmfile_docker_pdf/vmfile_docker_hostname/g" -c ":wq!"

# change first /root to $HOME ,not all

vi ./docker-compose_vm_hostname.yml -c ":%s#/root#$vmware_folder" -c ":wq!"
export GID=${GID}
echo $GID
server_start(){
  # start server
  docker-compose -p seafile -f ./docker-compose_vm_hostname.yml up -d
}

server_stop(){
  # stop server if server is running
  docker-compose -p seafile -f ./docker-compose_vm_hostname.yml down
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
#read -p "should we restart server ? y or n : " RESTART
RESTART=y
case $RESTART in
  y) echo $(server_restart) ;;
  n) echo "enjoying" ;;
esac
