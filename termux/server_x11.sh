#!/data/data/com.termux/files/usr/bin/bash
SCRIPT_NAME="x11"
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
sudo killall -9 termux-x11 Xwayland termux-wake-lock

sudo pkill -f com.termux.x11
sudo am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11
#sudo pkill -f com.termux.x11
clean_tmp
#TERMUX_X11_DEBUG=1 termux-x11 :1 -ac -xstartup "virgl_test_server_android"

## Start Termux X11
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
XDG_RUNTIME_DIR=${TMPDIR} TERMUX_X11_DEBUG=1 termux-x11 :1 -ac
