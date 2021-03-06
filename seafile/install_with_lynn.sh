#!/bin/zsh
vmware_folder=/mnt/lynnfile
hostname=$1
help_message="add your hostname as args"
greeting_message="now start process"
case $hostname in
  "")echo $help_message && exit;;
  *)echo "$greeting_message\nyour hostname is $hostname" ;;
esac
password=aserect
read "password?put your password?:"

#copy configure
cp ./docker-compose_vm_pdf.yml ./docker-compose_vm_lynn.yml

# change hostname

vi ./docker-compose_vm_lynn.yml -c ":%s/pdf.sherylynn.win/$hostname/g" -c ":wq!"

# change docker name
vi ./docker-compose_vm_lynn.yml -c ":%s/seafile-/lynnfile-/g" -c ":wq!"
vi ./docker-compose_vm_lynn.yml -c ":%s/lynnfile-mc/seafile-mc/g" -c ":wq!"

# link to new port
vi ./docker-compose_vm_lynn.yml -c ":%s/8000/8080/g" -c ":wq!"
vi ./docker-compose_vm_lynn.yml -c ":%s/8001/8081/g" -c ":wq!"

# change password
vi ./docker-compose_vm_lynn.yml -c ":%s/asecret/$password/g" -c ":wq!"
# change first /root to $HOME ,not all

vi ./docker-compose_vm_lynn.yml -c ":%s#/root#$vmware_folder" -c ":wq!"
export GID=${GID}
echo $GID
server_start(){
  # start server
  docker-compose -p lynnfile -f ./docker-compose_vm_lynn.yml up -d
}

server_stop(){
  # stop server if server is running
  docker-compose -p lynnfile -f ./docker-compose_vm_lynn.yml down
}

server_restart(){
  if [[ "$(docker ps -a |grep seafile)" == *"lynnfile"* ]] ;then
    echo $(server_stop )
    echo $(server_start )
  else
    echo $(server_start )
  fi
  echo "server finish"
}
read "RESTART?should we restart server ? y or n : "
case $RESTART in
  y) echo $(server_restart) ;;
  n) echo $(server_stop) ;;
esac
