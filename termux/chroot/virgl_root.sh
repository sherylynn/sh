#!/data/data/com.termux/files/usr/bin/bash

. $(dirname "$0")/cli.sh
# Kill all old prcoesses
sudo killall -9 Xwayland pulseaudio virgl_test_server_android termux-wake-lock

pkill -f com.termux.x11
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11
clean_tmp

sudo setenforce 0
export TMPDIR=$DEBIAN_DIR/tmp
export CLASSPATH=$(/system/bin/pm path com.termux.x11 | cut -d: -f2)
/system/bin/app_process / com.termux.x11.CmdEntryPoint :0

# Start Pulse Audio of Termux
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1

# Start virgl server
virgl_test_server_android &

#export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \
#export GTK_IM_MODULE="fcitx" && \
#export QT_IM_MODULE="fcitx" && \
#export XMODIFIERS="@im=fcitx" && \
#export GALLIUM_DRIVER=virpipe && \
#export MESA_GL_VERSION_OVERRIDE=4.0 && \
