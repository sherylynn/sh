command="*/15 * * * * ~/sh/termux/namesilo.sh >> ~/cron.log 2>&1"
#echo $command > ~/crontab_conf && crontab ~/crontab_conf
echo $command > $PREFIX/var/spool/cron/crontabs/$(whoami)
