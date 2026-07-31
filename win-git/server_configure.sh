#!/bin/bash
SCRIPT_NAME="configure"
#SOFT_VNC=kasmvnc
SOFT_VNC=tigervnc

# 容器类型检测: 在 proot-distro 环境下, 外部 (proot_cli.sh) 会设置 PROOT_CONTAINER=1
# 或通过检测是否存在 /.dockerenv 及是否挂载了 proot 的 /proc/self/status 来辅助
if [ -n "$PROOT_CONTAINER" ]; then
  CONTAINER_TYPE="proot"
elif [ -f /.dockerenv ] || grep -q "proot" /proc/self/status 2>/dev/null; then
  CONTAINER_TYPE="proot"
  export PROOT_CONTAINER=1
else
  CONTAINER_TYPE="chroot"
fi
echo "检测到容器类型: $CONTAINER_TYPE"
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

sudo apt install git vim wget curl sudo jq -y
git clone --depth 1 http://github.com/sherylynn/sh ~/sh
git -C ~/sh pull

#. ~/sh/win-git/toolsinit.sh
#zsh ~/sh/debian/testing_mirror.sh
#zsh ~/sh/debian/bullseyes_mirror.sh
#deepin
#sudo cp ~/sh/debian/sources.list.deepin /etc/apt/sources.list
if [ -d "/sdcard" ]; then
  sdcard_rime=/sdcard/Download/rime
  sdcard_ssh=/sdcard/Download/.ssh
  sdcard_gitconfig=/sdcard/Download/.gitconfig
  sdcard_gitcredentials=/sdcard/Download/.git-credentials
  sudo rm -rf ~/.gitconfig
  test -f $sdcard_gitconfig && sudo ln -s $sdcard_gitconfig ~/.gitconfig
  sudo rm -rf ~/.git-credentials
  test -f $sdcard_gitcredentials && sudo ln -s $sdcard_gitcredentials ~/.git-credentials
  #复用输入法词库
  sudo rm -rf ~/rime
  test -d $sdcard_rime && sudo ln -s $sdcard_rime ~/rime
  sudo ln -s /sdcard/Download/BaiduNetdisk/_pcs_.workspace/ /root/Documents/百度云盘
fi

sudo apt install zsh -y
sudo apt install telegram-desktop -y
sudo apt install ncdu htop android-platform-tools-base -y
sudo chsh -s /bin/zsh
. $(dirname "$0")/../win-git/toolsinit.sh
source ~/sh/win-git/toolsinit.sh
proxy
zsh ~/sh/raspberry/chinese.sh
zsh ~/sh/lynn.sh work
zsh ~/sh/win-git/move2zsh.sh
zsh ~/sh/win-git/zlua_new.sh
#如果没有安装kwin-wayland，则安装xfce+vnc环境
if ! dpkg -s kwin-wayland &>/dev/null; then
  DroidSpaces_path="/run/droidspaces/container.config"
  sudo apt install dbus-x11 xfce4 openssh-server -y
  sudo apt install xfce4-terminal -y
  if [[ $SOFT_VNC == *tigervnc* ]]; then
    zsh ~/sh/win-git/mesa.sh
    if [ -e "$DroidSpaces_path" ]; then
      zsh ~/sh/win-git/systemd_noVNC.sh
    else
      # proot 容器下, sysv init (/etc/rc3.d) 不会被执行
      # 因此仍生成 init.d 文件 (留作兼容), 但额外安装 proot-services.sh 作为主启动入口
      zsh ~/sh/win-git/init_d_noVNC.sh
      if [ "$CONTAINER_TYPE" = "proot" ]; then
        # 安装 proot 服务启动脚本 (由外部 proot_cli.sh 调用)
        if [ -f ~/sh/termux/chroot/proot-services.sh ]; then
          sudo install -m 755 ~/sh/termux/chroot/proot-services.sh /usr/local/bin/proot-services.sh
          echo "[proot] 已安装 /usr/local/bin/proot-services.sh (由 proot_cli.sh 调用启动所有服务)"
        else
          # 备用: 若宿主没有提供, 生成最小化版本
          cat <<'PROOT_EOF' | sudo tee /usr/local/bin/proot-services.sh >/dev/null
#!/bin/bash
export DISPLAY="${DISPLAY:-:1}"
export PULSE_SERVER="${PULSE_SERVER:-127.0.0.1}"
mkdir -p /run/dbus
case "${1:-start}" in
  start)
    ssh-keygen -A 2>/dev/null; /usr/sbin/sshd 2>/dev/null
    [ -s /etc/machine-id ] || dbus-uuidgen >/etc/machine-id 2>/dev/null
    dbus-daemon --system --fork 2>/dev/null
    [ -f ~/.vnc/passwd ] && command -v vncserver >/dev/null 2>&1 && vncserver :1 -geometry 1920x1080 -depth 24 2>&1 | tail -3
    ;;
  stop)
    pkill -x sshd 2>/dev/null; pkill -x dbus-daemon 2>/dev/null
    command -v vncserver >/dev/null 2>&1 && vncserver -kill :1 2>/dev/null
    ;;
  status)
    for n in sshd dbus-daemon Xvnc; do pgrep -x $n >/dev/null 2>&1 && echo "  ● $n" || echo "  ○ $n"; done
    ;;
esac
PROOT_EOF
          sudo chmod 755 /usr/local/bin/proot-services.sh
          echo "[proot] 已生成最小化 /usr/local/bin/proot-services.sh"
        fi
      fi
    fi
    zsh ~/sh/win-git/noVNC.sh
  else
    zsh ~/sh/win-git/kasmVNC.sh
  fi
fi
zsh ~/sh/win-git/koreader.sh
zsh ~/sh/debian/firefox.sh
if [[ $(platform) == *wsl* ]]; then
  sh ~/sh/win-git/ssh.sh
fi
#确保toolsrc正确
#zsh ~/sh/debian/firefox.sh
zsh ~/sh/debian/wps.sh
#zsh ~/sh/debian/todesk.sh
#todesk无法联网
zsh ~/sh/debian/wechat.sh
zsh ~/sh/win-git/qq.sh
#zsh ~/sh/debian/spark-store.sh
zsh ~/sh/debian/vlc.sh
# scrcpy 依赖 Android USB 调试层 /dev 以及 adb 直接访问 Android 系统
# chroot 下可用, proot 下经常出问题且没必要(通常 termux 端已提供 scrcpy)
if [ "$CONTAINER_TYPE" != "proot" ]; then
  zsh ~/sh/win-git/scrcpy.sh
else
  echo "[proot] 跳过 scrcpy 安装 (Android 调试通常直接在 Termux 端使用更稳定)"
fi
zsh ~/sh/myemacs.sh
zsh ~/sh/debian/emacs.sh
#zsh ~/sh/win-git/emacs.sh
zsh ~/sh/debian/R.sh
# proot 容器中常通过非交互式方式调用 (installer_proot.sh 中)
# 避免脚本阻塞, 仅在交互式终端时启动 emacs -nw
if [ -t 1 ] && [ "$CONTAINER_TYPE" != "proot" ]; then
  emacs -nw
elif [ -t 1 ]; then
  echo "[proot] 跳过自动启动 emacs -nw, 请按需手动执行 emacs"
fi
