#!/bin/bash
SCRIPT_NAME="configure"
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

sudo apt install git vim wget curl sudo jq aria2 -y
git clone --depth 1 http://github.com/sherylynn/sh ~/sh
git -C ~/sh pull

# 新系统拿到 sh 仓库后立即部署 apt-fast。apt update 仍由原生 APT 负责，
# 后续 install/upgrade 可直接使用 apt-fast + aria2 并行下载。
bash ~/sh/win-git/apt-fast.sh

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
# One persistent SSH-agent socket shared by all login shells (including chroot).
# The helper uses flock to avoid spawning a new agent per terminal.
sudo apt install -y openssh-client util-linux
bash ~/sh/win-git/ssh_agent_shared.sh
mkdir -p ~/tools/rc
cat > ~/tools/rc/sshagentrc <<'SSH_AGENT_RC'
if [ -r "$HOME/sh/win-git/ssh_agent_shared.sh" ]; then
  source "$HOME/sh/win-git/ssh_agent_shared.sh"
fi
SSH_AGENT_RC
if [ -f ~/tools/rc/allToolsrc ] && ! grep -Fq 'sshagentrc' ~/tools/rc/allToolsrc; then
  printf '\n%s\n' 'test -f ~/tools/rc/sshagentrc && . ~/tools/rc/sshagentrc' >> ~/tools/rc/allToolsrc
fi
#修复 zsh compinit: insecure directories 问题
#通过 zsh 的 compaudit 动态获取实际不安全目录,而非预设
CURRENT_USER=$(whoami)
INSECURE_DIRS=$(zsh -c 'autoload -Uz compaudit && compaudit' 2>/dev/null)
if [ -n "$INSECURE_DIRS" ]; then
  if [ "$CURRENT_USER" = "root" ]; then
    echo "$INSECURE_DIRS" | xargs chown -R $CURRENT_USER:$CURRENT_USER
  else
    echo "$INSECURE_DIRS" | xargs sudo chown -R $CURRENT_USER:$CURRENT_USER
  fi
fi
#清除旧的 compinit 缓存,避免使用旧的不安全记录
rm -f ~/.zcompdump* 2>/dev/null
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
# 如果没有安装 kwin-wayland，则安装 XFCE 用户环境。Android KGSL chroot 的
# display/RFB owner 固定为 NewHome native compositor，不再选择第二套 VNC server。
if ! dpkg -s kwin-wayland &>/dev/null; then
  sudo apt install dbus-x11 xfce4 openssh-server xfce4-terminal -y
  if [ -e /dev/kgsl-3d0 ]; then
    zsh ~/sh/win-git/mesa.sh
    zsh ~/sh/win-git/noVNC.sh || exit 1
    zsh ~/sh/win-git/init_d_noVNC.sh || exit 1
  else
    echo "非 Android KGSL 主机不由本脚本自动部署历史 VNC/X11 desktop server"
  fi
fi
# install_proot -> installer_proot.sh 会进入新 rootfs 调用本脚本；这里统一安装
# 麦克风桥和 XFCE 顶栏显示预设按钮。脚本幂等，可用于全新安装和升级。
if ! bash ~/sh/debian/termux_chroot_desktop_setup.sh; then
  echo "Termux chroot 桌面集成安装失败，停止系统配置。" >&2
  exit 1
fi
# Work/Chat 开发共用默认 Rust ADB；不覆盖发行版或 SDK 的原生二进制。
bash ~/sh/win-git/newhome_rust_adb_setup.sh || exit 1

# Android KGSL chroot 的显示服务端由 NewHome APK 自己提供。
# chroot 只安装 Wayland/XWayland 客户端、XFCE 和 native-RFB 的 noVNC frontend。
if [ -e /dev/kgsl-3d0 ]; then
  echo "检测到 Android KGSL chroot，安装 NewHome compositor 客户端依赖"
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wayland-utils xwayland xfce4-panel xfce4-terminal xfce4-settings \
    xfce4-notifyd thunar dbus-x11 procps coreutils python3 python3-gi \
    gir1.2-gtk-3.0 libnotify-bin glmark2-wayland

  # 清理旧 framebuffer owners；noVNC 已经只是 native RFB 的 Web frontend，
  # 必须保留 /etc/init.d/noVNC 与 rc3 链接。
  sudo service xrdp stop >/dev/null 2>&1 || true
  sudo update-rc.d xrdp disable >/dev/null 2>&1 || true
  sudo pkill -TERM -x x11vnc >/dev/null 2>&1 || true
  sudo pkill -TERM -x wayvnc >/dev/null 2>&1 || true
  sudo pkill -TERM -x xrdp >/dev/null 2>&1 || true
  zsh ~/sh/win-git/noVNC.sh || exit 1
  zsh ~/sh/win-git/init_d_noVNC.sh || exit 1
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
zsh ~/sh/win-git/scrcpy.sh
zsh ~/sh/myemacs.sh
zsh ~/sh/debian/emacs.sh
#zsh ~/sh/win-git/emacs.sh
zsh ~/sh/debian/R.sh
emacs -nw
