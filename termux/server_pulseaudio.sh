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

# PulseAudio 由 termux-services 前台托管。先启动一个短生命周期 watcher，
# 等 PulseAudio ready 后把默认 sink 切到 NewHome Android AudioTrack；
# watcher 随即退出，真正的 PCM worker 由 newhome_playback_bridge.sh 管理。
(
  for _ in $(seq 1 40); do
    sleep 0.25
    if pulseaudio --check >/dev/null 2>&1 || pgrep -x pulseaudio >/dev/null 2>&1; then
      PULSE_SERVER=tcp:127.0.0.1:4713 \
        bash "$HOME/sh/termux/newhome_playback_bridge.sh" start >/dev/null 2>&1 || true
      exit 0
    fi
  done
) &

# 但是这个东西要求有x环境，不然连不上dbus，实际运行发现报错不影响使用。
# 不使用 --start，让 termux-services 持有前台进程。
exec pulseaudio --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 port=4713" --exit-idle-time=-1
