echo "*/15 * * * * ~/sh/termux/namesilo.sh >> ~/cron.log 2>&1" > ~/crontab_conf && crontab ~/crontab_conf
