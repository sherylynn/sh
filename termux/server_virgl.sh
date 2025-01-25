#!/data/data/com.termux/files/usr/bin/bash
SCRIPT_NAME="virgl"
#change bash from /usr/bin/bash to realpath
realpath() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )/$x

}
realpathdir() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )

}
cd $(realpathdir ./server_${SCRIPT_NAME}.sh)
pwd
#load env
#test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(whoami)
. ./chroot/cli.sh

# Kill all old prcoesses
#sudo pkill -f "termux-x11|Xwayland|pulseaudio|virgl_test_server_android"
#sudo killall -9 $(pgrep -f "termux-x11|Xwayland|pulseaudio|virgl_test_server_android")
sudo killall -9 termux-x11 pulseaudio virgl_test_server_android
sudo pkill -f com.termux.x11
clean_tmp
#sudo setenforce 0
#从:0 换到:1
#XDG_RUNTIME_DIR=${TMPDIR} termux-x11 :1 -ac &
#如果按这样倒是也能跑
#TERMUX_X11_DEBUG=1 termux-x11 :1 -ac -xstartup "virgl_test_server_android"
#其实只是运行virgl的话。压根不需要跑termux-x11
virgl_test_server_android

#sleep 3
#echo 2
# Start Pulse Audio of Termux
#pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
#pulseaudio --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 &
#pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1

# Start virgl server
#virgl_test_server_android &
#virgl_test_server_android &
