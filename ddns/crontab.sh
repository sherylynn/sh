command="*/15 * * * * $HOME/sh/ddns/ddns_namesile.sh >> $HOME/cron.log 2>&1"
#echo $command > ~/crontab_conf && crontab ~/crontab_conf
#echo $command > $PREFIX/var/spool/cron/crontabs/$(whoami)
sudo tee /var/spool/cron/crontabs/$(whoami) <<-EOF
$command
EOF
