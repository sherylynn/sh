#每分钟执行
command="*/15 * * * * $HOME/sh/ddns/ddns_namesilo.sh >> $HOME/cron.log 2>&1"
test="*/1 * * * * $HOME/sh/ddns/test_echo.sh >> $HOME/cron_test.log 2>&1"
clear="0 0 * * 0 $HOME/sh/ddns/delete.sh"
#echo $command > ~/crontab_conf && crontab ~/crontab_conf
#echo $command > $PREFIX/var/spool/cron/crontabs/$(whoami)
tee $HOME/crontab.conf <<-EOF
$command
$test
$clear
EOF
crontab $HOME/crontab.conf
