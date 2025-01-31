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
#sudo pkill -f "termux-x11|Xwayland|pulseaudio|virgl_test_server_android"
#sudo killall -9 $(pgrep -f "termux-x11|Xwayland|pulseaudio|virgl_test_server_android")
#sudo killall -9 termux-x11 pulseaudio virgl_test_server_android

sudo killall -9 virgl_test_server_android
#sudo pkill -f com.termux.x11
clean_tmp
#TERMUX_X11_DEBUG=1 termux-x11 :1 -ac -xstartup "virgl_test_server_android"
XDG_RUNTIME_DIR=${TMPDIR} TERMUX_X11_DEBUG=1 termux-x11 :1 -ac
