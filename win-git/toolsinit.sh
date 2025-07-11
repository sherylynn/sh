#!/bin/zsh
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
if [[ $PREFIX == *termux* ]]; then
  alias uname=$PREFIX/bin/uname
elif [[ $TMPDIR == *emacs* ]]; then                     #/data/data/org.gnu.emacs/cache
  alias uname=/data/data/com.termux/files/usr/bin/uname #安卓上的 emacs 利用的地址是 termux 一样的地址
elif [[ $(which uname) == *usr* ]]; then
  alias uname=/usr/bin/uname #for msys2 which can't found uname in .zshenv
else
  alias uname=/bin/uname
fi

#
if [[ $(uname -a) == *raspberrypi* ]]; then
  alias uname=/bin/uname #for raspberrypi
fi

INSTALL_PATH=$HOME/tools
if [ ! -d "${INSTALL_PATH}" ]; then
  mkdir -p $INSTALL_PATH
fi
CACHE_FOLDER=$INSTALL_PATH/cache
BASH_DIR=$INSTALL_PATH/rc
BASH_FILE=~/.bash_profile
#ZSH_FILE=$HOME/.zprofile
ZSH_FILE=$HOME/.zshrc
ZSH_HOME=$HOME/sh

if [[ "$(uname -a)" == *x86_64* ]]; then
  ARCH=amd64
elif [[ "$(uname -a)" == *i686* ]]; then
  ARCH=386
elif [[ "$(uname -a)" == *armv8l* ]]; then
  case $(getconf LONG_BIT) in
    32) ARCH=armhf ;;
    64) ARCH=aarch64 ;;
  esac
elif [[ "$(uname -a)" == *aarch64* ]]; then
  case $(getconf LONG_BIT) in
    32) ARCH=armhf ;;
    64) ARCH=aarch64 ;;
  esac
elif [[ "$(uname -a)" == *armv7l* ]]; then
  ARCH=armhf
elif [[ "$(uname -a)" == *mips* ]]; then
  ARCH=mips
#for mac arm64
elif [[ "$(uname -a)" == *arm64* ]]; then
  ARCH=aarch64
fi

platform() {
  local PLATFORM=win
  if [[ "$(uname)" == *MINGW* ]]; then
    BASH_FILE=~/.bash_profile
    PLATFORM=win
  elif [[ "$(uname -a)" == *Microsoft* ]]; then
    BASH_FILE=~/.bashrc
    PLATFORM=wslinux
  elif [[ "$(uname)" == *Linux* ]]; then
    BASH_FILE=~/.bashrc
    PLATFORM=linux
  elif [[ "$(uname)" == *Darwin* ]]; then
    BASH_FILE=~/.bash_profile
    PLATFORM=macos
  elif [[ "$(uname)" == *Cgywin* ]]; then
    BASH_FILE=~/.bash_profile
    PLATFORM=win
  fi

  echo -n $PLATFORM
}
ALLTOOLSRC_FILE=$BASH_FILE
#platform
BASH_TYPE=bash
#zsh
if command -v zsh >/dev/null 2>&1; then
  ALLTOOLSRC_FILE=$BASH_DIR/allToolsrc
  if [[ "$(cat ${ZSH_FILE})" != *${ALLTOOLSRC_FILE}* ]]; then
    echo "test -f ${ALLTOOLSRC_FILE} && . ${ALLTOOLSRC_FILE}" >>${ZSH_FILE}
  fi
  BASH_TYPE=zsh
fi

arch() {
  echo $ARCH
}

toolsRC() {
  local toolsrc_name="$1"

  # 参数检查
  if [ -z "$toolsrc_name" ]; then
    echo "Error: toolsRC requires a toolsrc name parameter" >&2
    return 1
  fi

  # 变量安全检查
  if [ -z "$BASH_DIR" ] || [ -z "$ALLTOOLSRC_FILE" ]; then
    echo "Error: BASH_DIR or ALLTOOLSRC_FILE not set" >&2
    return 1
  fi

  local toolsrc="$BASH_DIR/${toolsrc_name}"
  local source_line="test -f ${toolsrc} && . ${toolsrc}"

  #--------------new .toolsrc-----------------------
  # 确保目录存在
  if [ ! -d "$BASH_DIR" ]; then
    if ! mkdir -p "$BASH_DIR"; then
      echo "Error: Failed to create directory $BASH_DIR" >&2
      return 1
    fi
  fi

  # 确保主配置文件存在
  if ! touch "$ALLTOOLSRC_FILE"; then
    echo "Error: Failed to create/touch $ALLTOOLSRC_FILE" >&2
    return 1
  fi

  # 检查是否已存在完全相同的行
  if grep -Fq "$source_line" "$ALLTOOLSRC_FILE" 2>/dev/null; then
    # 已存在完全相同的行，直接返回
    echo "$toolsrc"
    return 0
  fi

  # 删除旧的配置行 (如果存在)
  if grep -q "\\b${toolsrc_name}\\b" "$ALLTOOLSRC_FILE" 2>/dev/null; then
    # 使用更精确的正则表达式，只删除包含确切 toolsrc_name 的行
    if [[ $(platform) == macos ]]; then
      # macOS 的 sed 需要 ""
      if ! sed -i "" "/test -f.*${toolsrc_name}.*&&.*${toolsrc_name}/d" "$ALLTOOLSRC_FILE"; then
        echo "Warning: Failed to remove old entry for $toolsrc_name" >&2
      fi
    else
      if ! sed -i "/test -f.*${toolsrc_name}.*&&.*${toolsrc_name}/d" "$ALLTOOLSRC_FILE"; then
        echo "Warning: Failed to remove old entry for $toolsrc_name" >&2
      fi
    fi
  fi

  # 添加新的配置行
  if ! echo "$source_line" >>"$ALLTOOLSRC_FILE"; then
    echo "Error: Failed to add entry to $ALLTOOLSRC_FILE" >&2
    return 1
  fi

  echo "$toolsrc"
}

update_config() {
  local config_path="$1"
  local config_name="$2"
  local config_value="$3"
  local local_sudo="$4"

  # 参数检查
  if [ -z "$config_path" ] || [ -z "$config_name" ]; then
    echo "Error: update_config requires config_path and config_name parameters" >&2
    return 1
  fi

  #--------------new config----------------------
  # 确保配置文件存在
  if [ ! -f "$config_path" ]; then
    if ! $local_sudo touch "$config_path"; then
      echo "Error: Failed to create config file $config_path" >&2
      return 1
    fi
  fi

  # 检查配置是否已存在
  local config_line="${config_name} ${config_value}"
  if grep -Fq "$config_line" "$config_path" 2>/dev/null; then
    # 完全相同的配置已存在，直接返回
    return 0
  fi

  # 删除旧的配置行 (如果存在)
  if grep -q "^${config_name}\\s" "$config_path" 2>/dev/null; then
    if [[ $(platform) == macos ]]; then
      # macOS 的 sed 需要 ""
      if ! $local_sudo sed -i "" "/^${config_name}\\s/d" "$config_path"; then
        echo "Warning: Failed to remove old config for $config_name" >&2
      fi
    else
      if ! $local_sudo sed -i "/^${config_name}\\s/d" "$config_path"; then
        echo "Warning: Failed to remove old config for $config_name" >&2
      fi
    fi
  fi

  # 添加新的配置行
  if ! $local_sudo tee -a "$config_path" <<EOF; then
${config_name} ${config_value}
EOF
    echo "Error: Failed to add config to $config_path" >&2
    return 1
  fi
}

bash_file() {
  echo $BASH_FILE
}

bash_type() {
  echo $BASH_TYPE
}

alltoolsrc_file() {
  echo ${ALLTOOLSRC_FILE}
}

install_path() {
  echo $INSTALL_PATH
}

cache_folder() {
  if [[ ! -d $CACHE_FOLDER ]]; then
    mkdir -p $CACHE_FOLDER
  fi
  echo $CACHE_FOLDER
}

git_downloader() {
  local soft_file_pack=$1
  local soft_url=$2
  #if [[ ! -f $soft_file_pack ]]; then
  # use curl
  #curl -o $soft_file_pack $soft_url
  # use wget
  git clone $soft_url $soft_file_pack --depth 1
  #fi
}

cache_downloader() {
  local soft_file_pack=$1
  local soft_url=$2
  cd $(cache_folder)
  if [[ $soft_url != "" ]]; then
    #if [[ ! -f $soft_file_pack ]]; then
    # use curl
    #curl -o $soft_file_pack $soft_url
    # use wget
    wget -O $soft_file_pack -c $soft_url
  #fi
  else
    # not soft_url is empty; so soft_file_pack is url in fact
    local soft_url=$soft_file_pack
    wget -c $soft_url
  fi
  cd -
}

zget() {
  cache_downloader $1
}

cache_unpacker() {
  local soft_file_pack=$1
  local soft_file_name=$2
  cd $(cache_folder)
  if [ ! -d "${soft_file_name}" ]; then
    if [[ ${soft_file_pack} != *.* ]]; then
      mkdir ${soft_file_name}
      cp ${soft_file_pack} ${soft_file_name}/${soft_file_name}
      chmod 777 ${soft_file_name}/${soft_file_name}
    elif [[ ${soft_file_pack} == *exe* ]]; then
      mkdir ${soft_file_name}
      cp ${soft_file_pack} ${soft_file_name}/${name}.exe
    elif [[ ${soft_file_pack} == *zip* ]]; then
      unzip -q ${soft_file_pack} -d ${soft_file_name}
    elif [[ ${soft_file_pack} == *tgz* ]]; then
      mkdir ${soft_file_name}
      tar -xvzf ${soft_file_pack} -C ${soft_file_name}
    elif [[ ${soft_file_pack} != *tar* ]]; then
      mkdir -p ${soft_file_name}/${soft_file_name}
      gunzip -c ${soft_file_pack} >${soft_file_name}/${soft_file_name}/${soft_file_name}
    elif [[ ${soft_file_pack} == *bz2* ]]; then
      mkdir ${soft_file_name}
      tar -xf ${soft_file_pack} -C ${soft_file_name}
    elif [[ ${soft_file_pack} != *gz* ]]; then
      mkdir ${soft_file_name}
      tar -xf ${soft_file_pack} -C ${soft_file_name}
    elif [[ ${soft_file_pack} == *tar.gz* ]]; then
      mkdir ${soft_file_name}
      tar -xzf ${soft_file_pack} -C ${soft_file_name}
    fi
  fi

}

soft_file_pack() {
  local soft_file_name=$1
  local notar=$2

  if [[ $notar == bin ]]; then
    if [[ $(platform) == win ]]; then
      echo ${soft_file_name}.exe
    else
      echo ${soft_file_name}
    fi
  elif [[ $(platform) == win ]]; then
    echo ${soft_file_name}.zip
  elif [[ $notar == notar ]]; then
    echo ${soft_file_name}.gz
  elif [[ $notar == deb ]]; then
    echo ${soft_file_name}.deb
  else
    echo ${soft_file_name}.tar.gz
  fi
}

get_github_release_version() {
  local author_softname=$1
  curl --silent "https://api.github.com/repos/${author_softname}/releases/latest" |
    grep '"tag_name":' |
    awk -F '["]' '{print $4}'
}

get_gitee_release_version() {
  local author_softname=$1
  curl --silent "https://gitee.com/api/v5/repos/${author_softname}/releases/latest" |
    jq -r ".tag_name"
}

version_without_prefix_v() {
  local version=$1
  echo ${version#"v"}
}

zshenv() {
  echo "$HOME/.zshenv"
  # .zshenv 的使用还有问题,访问不到 uname
  # 无法把 toolsinit 都放进去
}

exportf() {
  local func_name=$1
  if [[ $SHELL == *bash* ]]; then
    export -f $func_name
  else
    tee $(zshenv) <<EOF
$(declare -f $func_name) 
EOF
  fi
}

update() {
  git -C $HOME/sh pull
  $HOME/sh/win-git/move2zsh.sh
  zs
}
#$(exportf exist)
#会有问题

distro() {
  source /etc/os-release && echo "$ID"
}

#bindkey
###############################
exist() {
  #autoload -X
  local COMMAND=$1
  if command -v $1 >/dev/null 2>&1; then
    echo 1
  else
    echo 0
  fi
}
if [[ "$(arch)" == "aarch64" ]]; then
  alias codium="LD_PRELOAD=$HOME/lib/libxcb.so.1 codium"
  alias ncdu="ncdu --exclude /root/download --exclude /proc --exclude /vendor --exclude /system --exclude /sdcard"
fi

if [[ $PREFIX == *termux* ]]; then
  alias ncdu="ncdu --exclude /root/download --exclude /proc --exclude /vendor --exclude /system --exclude ~/Desktop/chrootdebian/sdcard --exclude ~/Desktop/chrootdebian/proc"
fi

if [[ "$(platform)" == "win" ]]; then
  EDITOR=vim
  export EDITOR=vim
  #code()
  #{
  #  "C:/\Users\lynn\AppData\Local\Programs\Microsoft VS Code\Code.exe" $1
  #  "C:\Program Files\Microsoft VS Code\Code.exe" $1
  #  "Code.exe" $1
  #}
elif [[ "$(whoami)" == "root" ]]; then
  alias code='code --no-sandbox --user-data-dir /root/tools/vscode'
else
  if [[ $(exist nvim) == 1 ]]; then
    EDITOR=nvim
    export EDITOR=nvim
  else
    EDITOR=vim
    export EDITOR=vim
  fi
fi
if [[ "$(platform)" == "macos" ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color'
fi
alias go_win="GOOS=windows GOARCH=amd64 go build "

#alias ec="emacsclient ~/sh/win-git/toolsinit.sh"
zedit() {
  local filename="$1"
  if [[ -z "$filename" ]]; then
    #emacsclient -a "" -c "./"
    #希望能看到原来的窗口而不是新建一个
    #可用
    emacsclient -a "" "./"
    #指定端口，会有一些冲突
    #emacsclient -a "" "./" --server-file "$HOME/.emacs.d/server/server"
  elif [[ ! -f "$filename" ]]; then
    zluaload "$filename"
    #emacsclient -a "" -c "./"
    #可用
    emacsclient -a "" "./"
    #指定端口，会有一些冲突
    #emacsclient -a "" "./" --server-file "$HOME/.emacs.d/server/server"
  else
    #emacsclient -a "" -c "$filename"
    #可用
    emacsclient -a "" "$filename"
    #指定端口，会有一些冲突
    #emacsclient -a "" "$filename" --server-file "$HOME/.emacs.d/server/server"
  fi
}
alias zs="zedit ~/sh/win-git/toolsinit.sh"
alias zo="zedit ~/work/todo.org"

# as start function
#  case $(platform) in
#    win) alias zd="explorer" ;;
#    linux) alias zd="xdg-open" ;;
#    macos) alias zd="open" ;;
#  esac
zluaload() {
  $(which _zlua)
  _zlua $1
}
zd() {
  zluaload $1
  case $(platform) in
    #win) start . ;;
    win) explorer . ;;
    wslinux) explorer.exe . ;;
    #linux) xdg-open .;;
    linux) if [[ $(exist thunar) == 1 ]]; then
      thunar .
    else
      xdg-open .
    fi ;;
    macos) open ./ ;;
  esac
}
zdw() {
  #wsl
  zluaload $1
  /mnt/c/Windows/explorer.exe .
}
zcode() {
  zluaload $1
  code ./
}
alias chromium="chromium --no-sandbox"

zreload() {
  source $ZSH_HOME/win-git/toolsinit.sh
}
#zedit() {
#  $EDITOR $ZSH_HOME/win-git/toolsinit.sh
#}
zgit() {
  #$EDITOR -C "gs"
  git -C $ZSH_HOME commit -a
}
zgitstatus() {
  #$EDITOR -C "gs"
  git -C $ZSH_HOME status
}
zgitaddall() {
  #$EDITOR -C "gs"
  git -C $ZSH_HOME add --all
}
zpush() {
  test -d $ZSH_HOME && git -C $ZSH_HOME push &
  test -d ~/.emacs.d && git -C ~/.emacs.d/ push &
  test -d ~/work && git -C ~/work/ push &
  test -d ~/toys && git -C ~/toys/ push &
  echo push
}
zfetch() {
  test -d $ZSH_HOME && git -C $ZSH_HOME pull &
  test -d ~/.emacs.d && git -C ~/.emacs.d/ pull &
  test -d ~/work && git -C ~/work/ pull &
  test -d ~/toys && git -C ~/toys/ pull &
  echo git fetch
}

zchat() {
  /Applications/WeChat.app/Contents/MacOS/WeChat
}

ztermuxpaste() {
  echo $(termux-clipboard-get)
}
zxserver_scale() {
  local SCALE=$1
  export DISPLAY=:0.0
  export GDK_DPI_SCALING=$SCALE
}
zxserver() {
  local normal_scale=1
  zxserver_scale $normal_scale
}
virgl() {
  #export DISPLAY=:0
  export PULSE_SERVER=127.0.0.1
  export GTK_IM_MODULE="fcitx"
  export QT_IM_MODULE="fcitx"
  export XMODIFIERS="@im=fcitx"
  export GALLIUM_DRIVER=virpipe
  export MESA_GL_VERSION_OVERRIDE=4.0
}

alias zc="zcode"
alias zg="zgit"
alias zgs="zgitstatus"
alias zga="zgitaddall"
alias zp="zpush"
alias zf="zfetch"
alias zr="zreload"
alias ze="zedit"
alias ztp="ztermuxpaste"
alias zx="zxserver"
#bindkey -e

wsl_ip() {
  cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }' | grep -oE "192.168.[0-9]{1,3}.[0-9]{1,3}" | grep -vE "255"
}

wsl_adb() {
  local_ip=$1
  if [[ $local_ip != "" ]]; then
    adb connect $local_ip:5555
  else
    # 根据用户规则，默认连接到 192.168.1.133
    adb connect 192.168.1.133:5555
  fi
}

# 添加切换到谷歌输入法的函数
switch_to_google_ime() {
  local target_device=$1
  echo "正在切换到谷歌输入法..."

  if [[ $target_device != "" ]]; then
    # 如果指定了设备，使用指定设备
    adb -s "$target_device" shell ime set com.google.android.inputmethod.latin/.LatinIME 2>/dev/null ||
      adb -s "$target_device" shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME 2>/dev/null ||
      echo "警告：无法切换到谷歌输入法，请确保已安装谷歌输入法"
  else
    # 没有指定设备，使用默认连接
    adb shell ime set com.google.android.inputmethod.latin/.LatinIME 2>/dev/null ||
      adb shell ime set com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME 2>/dev/null ||
      echo "警告：无法切换到谷歌输入法，请确保已安装谷歌输入法"
  fi

  echo "输入法切换完成"
}

# 添加切换到讯飞输入法的函数
switch_to_xunfei_ime() {
  local target_device=$1
  echo "正在切换回讯飞输入法..."

  if [[ $target_device != "" ]]; then
    # 如果指定了设备，使用指定设备
    adb -s "$target_device" shell ime set com.iflytek.inputmethod/.FlyIME 2>/dev/null ||
      adb -s "$target_device" shell ime set com.iflytek.inputmethod/com.iflytek.inputmethod.FlyIME 2>/dev/null ||
      echo "警告：无法切换到讯飞输入法，请确保已安装讯飞输入法"
  else
    # 没有指定设备，使用默认连接
    adb shell ime set com.iflytek.inputmethod/.FlyIME 2>/dev/null ||
      adb shell ime set com.iflytek.inputmethod/com.iflytek.inputmethod.FlyIME 2>/dev/null ||
      echo "警告：无法切换到讯飞输入法，请确保已安装讯飞输入法"
  fi

  echo "讯飞输入法切换完成"
}

#连接无线调试的设备
wifi_adb() {
  local_ip=$1
  if [[ $local_ip == "" ]]; then
    #如果留空，则设置为默认地址
    local_ip=127.0.0.1
  fi
  adb kill-server
  #不重启服务，节省一点点时间
  PORTS=$(nmap -sT -p30000-45000 --open $local_ip | grep "open" | sed -r 's/([1-9][0-9]+)(\/tcp.+)/\1/')
  for PORT in $PORTS; do
    if [ -n "$PORT" ]; then
      RESULT=$(adb connect $local_ip:"$PORT")
    fi
    if [[ "$RESULT" =~ "" && ! "$RESULT" =~ "already" && ! "$RESULT" =~ "failed" ]]; then
      :
    elif [[ "$RESULT" =~ "connected" && ! "$RESULT" =~ "already" ]]; then
      echo "$RESULT"
      echo "adb $local_ip 5555"
      TCPPORT=$(echo "$RESULT" | sed -e "s/connected to //g")
      #echo "$TCPPORT"
      #选择指定设备的 adb，然后重新设置端口为 5555
      # 这个命令好像会影响无线调试，会直接失败，但是在 termux 里就能行，奇怪
      #adb -s "$TCPPORT" tcpip 5555
      # 在启动 scrcpy 前切换到谷歌输入法
      switch_to_google_ime "$TCPPORT"
      scrcpy -s "$TCPPORT" --turn-screen-off --stay-awake --keyboard=uhid
      # scrcpy 结束后切换回讯飞输入法
      switch_to_xunfei_ime "$TCPPORT"
    fi
  done
  #scrcpy --turn-screen-off --stay-awake --keyboard=uhid
  #adb connect $local_ip
}

wsl_ssh() {
  ssh root@$(wsl_ip)
  ssh root@$(wsl_ip) -p 8022
}

wsl_port() {
  local PORT=$1
  open http://$(wsl_ip):$PORT
}

wsl_vnc() {
  open http://$(wsl_ip):10086/vnc.html
}

wsl_ttyd() {
  open http://$(wsl_ip):3333
}

wsl_proxy() {
  proxy_ip $(wsl_ip)
}
alias proxy_wsl="wsl_proxy"

proxy_adb() {
  wsl_adb
  adb forward tcp:10808 tcp:1080868
  proxy_wsl
}

phone() {
  adb forward tcp:3333 tcp:3333
  adb forward tcp:8888 tcp:8888
  adb forward tcp:10001 tcp:10001
  adb forward tcp:10086 tcp:10086
  adb forward tcp:5900 tcp:5900
  adb forward tcp:10808 tcp:10808
  #open http://127.0.0.1:3333
  scrcpy_adb
}

scrcpy_adb() {
  local_ip=$1
  if [[ $local_ip != "" ]]; then
    #tcpip 命令会尝试直接重新连接 adb 指定地址
    #所以废弃直接用 wsl 来连接
    #wsl_adb $local_ip
    # 连接设备
    adb connect $local_ip:5555
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --no-audio --tcpip=$local_ip:5555 --screen-off-timeout=3000 --turn-screen-off
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
  else
    wsl_adb
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --no-audio --screen-off-timeout=3000 --turn-screen-off
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
  fi
  #scrcpy --turn-screen-off --stay-awake --keyboard=aoa
  #scrcpy 3.0
  #scrcpy --new-display=1080x1920 --start-app=com.atomicadd.tinylauncher
  #scrcpy --new-display --start-app=com.nightmare.sula
  #scrcpy --new-display --start-app=com.microsoft.launcher --keyboard=uhid
}
scrcpy_new() {
  local_ip=$1
  if [[ $local_ip != "" ]]; then
    # 连接设备
    adb connect $local_ip:5555
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    #scrcpy --new-display=1080x1920 --start-app=com.microsoft.launcher --tcpip=$local_ip:5555 --stay-awake --keyboard=uhid #--display-id=0
    scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --no-audio --tcpip=$local_ip:5555 --new-display --no-vd-destroy-content --screen-off-timeout=3000
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
  else
    wsl_adb
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    #scrcpy --new-display=1080x1920 --start-app=com.microsoft.launcher --stay-awake --keyboard=uhid #--display-id=0
    scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --no-audio --new-display --start-app=com.microsoft.launcher --no-vd-destroy-content --screen-off-timeout=3000
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
  fi
}

scrcpy_origin() {
  local_ip=$1
  if [[ $local_ip != "" ]]; then
    # 连接设备
    adb connect $local_ip:5555
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    #scrcpy --new-display=1080x1920 --start-app=com.microsoft.launcher --tcpip=$local_ip:5555 --stay-awake --keyboard=uhid #--display-id=0
    scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --no-audio --tcpip=$local_ip:5555 --new-display --no-vd-destroy-content --screen-off-timeout=3000
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
  else
    wsl_adb
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    #scrcpy --new-display=1080x1920 --start-app=com.microsoft.launcher --stay-awake --keyboard=uhid #--display-id=0
    scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --no-audio --new-display --no-vd-destroy-content --screen-off-timeout=3000
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
  fi
}

scrcpy_audio() {
  local_ip=$1
  if [[ $local_ip != "" ]]; then
    # 连接设备
    adb connect $local_ip:5555
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    #scrcpy --new-display=1080x1920 --start-app=com.microsoft.launcher --tcpip=$local_ip:5555 --stay-awake --keyboard=uhid #--display-id=0
    scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --tcpip=$local_ip:5555 --new-display --start-app=com.microsoft.launcher --no-vd-destroy-content --screen-off-timeout=3000
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
  else
    wsl_adb
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    #scrcpy --new-display=1080x1920 --start-app=com.microsoft.launcher --stay-awake --keyboard=uhid #--display-id=0
    scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --new-display --start-app=com.microsoft.launcher --no-vd-destroy-content --screen-off-timeout=3000
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
  fi
}

scrcpy_big() {
  local_ip=$1
  if [[ $local_ip != "" ]]; then
    # 连接设备
    adb connect $local_ip:5555
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    #scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --no-audio --tcpip=$local_ip:5555 --new-display=2560x1600/480 --start-app=com.microsoft.launcher --no-vd-destroy-content --screen-off-timeout=3000
    scrcpy --keyboard=uhid --video-codec=h265 --max-size=2560 --max-fps=60 --no-audio --tcpip=$local_ip:5555 --new-display=2560x1600/480 --no-vd-destroy-content #--window-borderless --fullscreen
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
    #scrcpy --stay-awake --keyboard=uhid --max-size=2560 --video-codec=h265 --max-fps=60 --no-audio --tcpip=$local_ip:5555 --new-display=2376x1080/640 --start-app=com.microsoft.launcher --no-vd-destroy-content --screen-off-timeout=3000
  else
    wsl_adb
    # 在启动 scrcpy 前切换到谷歌输入法
    switch_to_google_ime
    #scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=1920 --max-fps=60 --no-audio --new-display=2560x1600/480 --start-app=com.microsoft.launcher --no-vd-destroy-content --screen-off-timeout=3000
    scrcpy --stay-awake --keyboard=uhid --video-codec=h265 --max-size=2560 --max-fps=60 --no-audio --new-display=2560x1600/480 --start-app=com.microsoft.launcher --no-vd-destroy-content --screen-off-timeout=3000
    # scrcpy 结束后切换回讯飞输入法
    switch_to_xunfei_ime
    #scrcpy --stay-awake --keyboard=uhid --max-size=2560 --video-codec=h265 --max-fps=60 --no-audio --new-display=3168x1440/640 --start-app=com.microsoft.launcher --no-vd-destroy-content --screen-off-timeout=3000
  fi
}
# 快速连接到默认设备的函数
quick_connect() {
  echo "正在连接到默认设备 192.168.1.133..."
  scrcpy_adb 192.168.1.133
}

# 快速连接到默认设备的大屏模式
quick_connect_big() {
  echo "正在连接到默认设备 192.168.1.133 (大屏模式)..."
  scrcpy_big 192.168.1.133
}

# 快速连接到默认设备的新显示模式
quick_connect_new() {
  echo "正在连接到默认设备 192.168.1.133 (新显示模式)..."
  scrcpy_new 192.168.1.133
}

alias scb='scrcpy_big'
alias sca='scrcpy_new'
alias sco='scrcpy_origin'
alias scn='scrcpy_new'
alias sc='scrcpy_adb'
alias qc='quick_connect'
alias qcb='quick_connect_big'
alias qca='quick_connect_new'
scrcpy_termux_hold_video() {
  scrcpy --turn-screen-off --no-audio --video-bit-rate 1 --max-fps 1 --verbosity error
}

scrcpy_termux_hold_audio() {
  scrcpy --turn-screen-off --no-video --verbosity error
}

hotspot_ip() {
  #cat /etc/resolv.conf | grep 192.168.43 | awk '{ print $2}'
  local local_ip=0.0.0.0
  if [[ $(exist ifconfig) == 1 ]]; then
    local_ip=$(ifconfig)
    #ifconfig |grep -oE "192.168.[0-9]{1,3}.[0-9]{1,3}" |grep -vE "255"
  elif [[ $(exist ip) == 1 ]]; then
    local_ip=$(ip address)
    #ip address |grep -oE "192.168.[0-9]{1,3}.[0-9]{1,3}" |grep -vE "255"
  else
    local_ip=$(hostname -I)
    #hostname -I |grep -oE "192.168.[0-9]{1,3}.[0-9]{1,3}" |grep -vE "255"
  fi
  echo $local_ip | grep -oE "(192.168|172.27).[0-9]{1,3}.[0-9]{1,3}" | grep -vE "255"
}

ssh_hotspot() {
  ssh maru@$(hotspot_ip)
}

proxy_ip() {
  local IP=$1
  local PROXY_PORT=${2:-10808}
  local PROXY_TYPE=${3:-http}
  local TOOLSRC_NAME=proxyrc
  local TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

  # 参数检查
  if [ -z "$IP" ]; then
    echo "使用方法: proxy_ip <IP地址> [端口] [协议类型]"
    echo "例如: proxy_ip 192.168.1.1"
    echo "     proxy_ip 192.168.1.1 7890"
    echo "     proxy_ip 192.168.1.1 7890 socks5"
    return 1
  fi

  cat >${TOOLSRC} <<EOF
export http_proxy=${PROXY_TYPE}://$IP:${PROXY_PORT}
export https_proxy=${PROXY_TYPE}://$IP:${PROXY_PORT}
EOF

  export http_proxy=${PROXY_TYPE}://$IP:${PROXY_PORT}
  export https_proxy=${PROXY_TYPE}://$IP:${PROXY_PORT}

  git config --global http.proxy ${PROXY_TYPE}://$IP:${PROXY_PORT}
  git config --global https.proxy ${PROXY_TYPE}://$IP:${PROXY_PORT}

  echo "✅ 系统和 Git 代理已设置:"
  echo "   HTTP:  ${PROXY_TYPE}://$IP:${PROXY_PORT}"
  echo "   HTTPS: ${PROXY_TYPE}://$IP:${PROXY_PORT}"
  echo ""
  echo "💡 系统环境变量: http_proxy, https_proxy"
  echo "💡 Git 全局配置: http.proxy, https.proxy"
  echo "💡 查看状态: proxys 或 pgits"
  echo "💡 取消代理: unproxy"
}

proxy_git_ip() {
  local IP=$1
  local PROXY_PORT=${2:-10808}
  local PROXY_TYPE=${3:-http}

  # 参数检查
  if [ -z "$IP" ]; then
    echo "使用方法: proxy_git_ip <IP地址> [端口] [协议类型]"
    echo "例如: proxy_git_ip 192.168.1.1"
    echo "     proxy_git_ip 192.168.1.1 7890"
    echo "     proxy_git_ip 192.168.1.1 7890 socks5"
    return 1
  fi

  # 设置 Git 代理
  git config --global http.proxy ${PROXY_TYPE}://$IP:${PROXY_PORT}
  git config --global https.proxy ${PROXY_TYPE}://$IP:${PROXY_PORT}

  echo "✅ Git 代理已设置:"
  echo "   HTTP:  ${PROXY_TYPE}://$IP:${PROXY_PORT}"
  echo "   HTTPS: ${PROXY_TYPE}://$IP:${PROXY_PORT}"
  echo ""
  echo "💡 查看当前配置: git config --global --get-regexp 'http.*proxy'"
  echo "💡 取消代理设置: unproxy_git"
}

unproxy() {
  local TOOLSRC_NAME=proxyrc
  local TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
  if [ -f "$TOOLSRC" ]; then
    echo -n >"$TOOLSRC"
  fi

  unset http_proxy
  unset https_proxy

  git config --global --unset http.proxy 2>/dev/null || true
  git config --global --unset https.proxy 2>/dev/null || true

  echo "✅ 系统和 Git 代理已清除"
  echo "💡 系统环境变量: http_proxy, https_proxy 已取消设置"
  echo "💡 Git 全局配置: http.proxy, https.proxy 已清除"
  echo "💡 验证清除结果: proxys 或 pgits"
}

unproxy_git() {
  # 只取消 Git 代理设置，不影响系统环境变量
  git config --global --unset http.proxy 2>/dev/null || true
  git config --global --unset https.proxy 2>/dev/null || true

  echo "✅ Git 代理已清除"
  echo "💡 验证清除结果: git config --global --get-regexp 'http.*proxy'"
}

proxy() {
  # 本地代理，支持自定义端口和协议
  local normal_IP=127.0.0.1
  local port=${1:-10808}
  local protocol=${2:-http}
  proxy_ip $normal_IP $port $protocol
}

proxyu() {
  # USB 共享网络代理，支持自定义端口和协议
  local normal_IP=192.168.1.1
  local port=${1:-10808}
  local protocol=${2:-http}
  proxy_ip $normal_IP $port $protocol
}

proxyw() {
  # WSL 代理，支持自定义端口和协议
  local normal_IP=$(wsl_ip)
  local port=${1:-10808}
  local protocol=${2:-http}
  if [ -n "$normal_IP" ]; then
    proxy_ip $normal_IP $port $protocol
  else
    echo "❌ 无法获取 WSL IP 地址"
    return 1
  fi
}

proxys() {
  # 显示完整的代理状态
  echo "🔍 当前系统代理状态:"
  if [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
    [ -n "$http_proxy" ] && echo "   HTTP:  $http_proxy"
    [ -n "$https_proxy" ] && echo "   HTTPS: $https_proxy"
  else
    echo "   系统环境变量未设置代理"
  fi

  echo ""
  echo "🔍 当前 Git 代理状态:"
  local http_proxy_config=$(git config --global --get http.proxy 2>/dev/null)
  local https_proxy_config=$(git config --global --get https.proxy 2>/dev/null)

  if [ -n "$http_proxy_config" ] || [ -n "$https_proxy_config" ]; then
    [ -n "$http_proxy_config" ] && echo "   HTTP:  $http_proxy_config"
    [ -n "$https_proxy_config" ] && echo "   HTTPS: $https_proxy_config"
  else
    echo "   Git 全局配置未设置代理"
  fi
}

# Git 专用代理便捷函数
proxy_git() {
  # 本地代理，支持自定义端口和协议
  local normal_IP=127.0.0.1
  local port=${1:-10808}
  local protocol=${2:-http}
  proxy_git_ip $normal_IP $port $protocol
}

proxy_git_usb() {
  # USB 共享网络代理，支持自定义端口和协议
  local normal_IP=192.168.1.1
  local port=${1:-10808}
  local protocol=${2:-http}
  proxy_git_ip $normal_IP $port $protocol
}

proxy_git_wsl() {
  # WSL 代理，支持自定义端口和协议
  local normal_IP=$(wsl_ip)
  local port=${1:-10808}
  local protocol=${2:-http}
  if [ -n "$normal_IP" ]; then
    proxy_git_ip $normal_IP $port $protocol
  else
    echo "❌ 无法获取 WSL IP 地址"
    return 1
  fi
}

proxy_git_status() {
  # 显示当前 Git 代理状态
  echo "🔍 当前 Git 代理配置:"
  local http_proxy_config=$(git config --global --get http.proxy 2>/dev/null)
  local https_proxy_config=$(git config --global --get https.proxy 2>/dev/null)

  if [ -n "$http_proxy_config" ] || [ -n "$https_proxy_config" ]; then
    [ -n "$http_proxy_config" ] && echo "   HTTP:  $http_proxy_config"
    [ -n "$https_proxy_config" ] && echo "   HTTPS: $https_proxy_config"
  else
    echo "   未设置代理"
  fi
}

# 添加便捷别名
alias pgit='proxy_git'         # 设置本地 Git 代理
alias pgitip='proxy_git_ip'    # 根据 IP 设置 Git 代理
alias pgitu='proxy_git_usb'    # USB 代理
alias pgitw='proxy_git_wsl'    # WSL 代理
alias pgits='proxy_git_status' # 查看状态
alias upgit='unproxy_git'      # 取消代理

node_split() {
  node -e "console.log('$1'.split('$2')[$3])"
}

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache

alias armake="ARCH=arm64 make"

export HOMEBREW_NO_AUTO_UPDATE=true

realScriptPath() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )/$x

}

realScriptPathDir() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )

}
