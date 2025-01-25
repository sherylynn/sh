#!/data/data/com.termux/files/usr/bin/bash
SCRIPT_NAME="pulseaudio"
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
test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(whoami)
. ./chroot/cli.sh

# Kill all old prcoesses
sudo killall -9 pulseaudio

clean_tmp

#从:0 换到:1
#XDG_RUNTIME_DIR=${TMPDIR}

# Start Pulse Audio of Termux
#pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
#去掉--start来让termux services管理进程

#但是这个东西要求有x环境，不然连不上dbus，实际运行发现报错不影响使用
pulseaudio --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
