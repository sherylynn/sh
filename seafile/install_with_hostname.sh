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

server_restart(){
  if [[ $(docker ps -a |grep seafile)!= *seafile* ]] ;then
    # start server
    docker-compose -f ./docker-compose_caddy_hostname.yml up -d
  else
    # stop server if server is running
    docker-compose -f ./docker-compose_caddy_hostname.yml down
  fi
}
read -p "should we restart server ? y or n ?" RESTART
case $RESTART in
  y) $(server_restart) ;;
  n) echo "enjoying" ;;
esac
