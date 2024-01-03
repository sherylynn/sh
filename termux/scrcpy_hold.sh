#!/data/data/com.termux/files/usr/bin/bash
#. $(dirname "$0")/../win-git/toolsinit.sh

PORTS=`nmap -sT -p30000-45000 --open localhost | grep "open" | sed -r 's/([1-9][0-9]+)(\/tcp.+)/\1/'`
for PORT in $PORTS
do
if [ -n "$PORT" ];then
RESULT=`adb connect localhost:"$PORT"`
fi
if [[ "$RESULT" =~ "" && ! "$RESULT" =~ "already" && ! "$RESULT" =~ "failed" ]];then
:
elif [[ "$RESULT" =~ "connected" && ! "$RESULT" =~ "already" ]];then
echo "$RESULT"
echo "adb tcpip 5555"
TCPPORT=`echo "$RESULT" | sed -e "s/connected to //g"`  
#echo "$TCPPORT"
adb -s "$TCPPORT" tcpip 5555
fi
done
adb connect 127.0.0.1
scrcpy --tcpip=127.0.0.1:5555 --turn-screen-off --no-video --verbosity error
