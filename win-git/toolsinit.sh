#!/bin/zsh
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
if [[ $PREFIX == *termux*  ]]; then
  alias uname=$PREFIX/bin/uname
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
    32) ARCH=armhf;;
    64) ARCH=aarch64;;
  esac
elif [[ "$(uname -a)" == *aarch64* ]]; then
  case $(getconf LONG_BIT) in 
    32) ARCH=armhf;;
    64) ARCH=aarch64;;
  esac
elif [[ "$(uname -a)" == *armv7l* ]]; then
  ARCH=armhf
elif [[ "$(uname -a)" == *mips* ]]; then
  ARCH=mips
#for mac arm64
elif [[ "$(uname -a)" == *arm64* ]]; then
  ARCH=aarch64
fi

platform(){
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

  echo $PLATFORM
}
ALLTOOLSRC_FILE=$BASH_FILE
#platform
BASH_TYPE=bash
#zsh
if command -v zsh >/dev/null 2>&1; then
  ALLTOOLSRC_FILE=$BASH_DIR/allToolsrc
  if [[ "$(cat ${ZSH_FILE})" != *${ALLTOOLSRC_FILE}* ]]; then
    echo "test -f ${ALLTOOLSRC_FILE} && . ${ALLTOOLSRC_FILE}" >> ${ZSH_FILE}
  fi
  BASH_TYPE=zsh
fi

arch(){
  echo $ARCH
}

toolsRC(){
  local toolsrc_name=$1
  local toolsrc=$BASH_DIR/${toolsrc_name}
  #--------------new .toolsrc-----------------------
  if [ ! -d "${BASH_DIR}" ]; then
    mkdir $BASH_DIR
  fi
  touch ${ALLTOOLSRC_FILE}
  if [[ "$(cat ${ALLTOOLSRC_FILE})" != *${toolsrc_name}* ]]; then
    echo "not exist ${toolsrc}"
  else
    if [[ $(platform) == macos ]]; then
      #fuck sed in mac need ""
      sed -i "" '/'${toolsrc_name}'/d' ${ALLTOOLSRC_FILE}
    else
      sed -i '/'${toolsrc_name}'/d' ${ALLTOOLSRC_FILE}
    fi
  fi
  echo "test -f ${toolsrc} && . ${toolsrc}" >> ${ALLTOOLSRC_FILE}
  echo $toolsrc
}

bash_file(){
  echo $BASH_FILE
}

bash_type(){
  echo $BASH_TYPE
}

alltoolsrc_file(){
  echo ${ALLTOOLSRC_FILE}
}

install_path(){
  echo $INSTALL_PATH
}

cache_folder(){
  if [[ ! -d $CACHE_FOLDER ]]; then
    mkdir -p $CACHE_FOLDER
  fi
  echo $CACHE_FOLDER
}

git_downloader(){
  local soft_file_pack=$1
  local soft_url=$2
  #if [[ ! -f $soft_file_pack ]]; then
    # use curl
    #curl -o $soft_file_pack $soft_url
    # use wget
    git clone $soft_url $soft_file_pack  --depth 1
  #fi
}

cache_downloader(){
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

zget(){
  cache_downloader $1
}

cache_unpacker(){
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
    elif [[ ${soft_file_pack} != *tar* ]]; then
      mkdir -p ${soft_file_name}/${soft_file_name}
      gunzip -c ${soft_file_pack} > ${soft_file_name}/${soft_file_name}/${soft_file_name}
    elif [[ ${soft_file_pack} == *bz2* ]]; then
      mkdir ${soft_file_name}
      tar -xf ${soft_file_pack} -C ${soft_file_name}
    else
      mkdir ${soft_file_name}
      tar -xzf ${soft_file_pack} -C ${soft_file_name}
    fi
  fi

}

soft_file_pack(){
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

get_github_release_version(){
  local author_softname=$1
  curl --silent "https://api.github.com/repos/${author_softname}/releases/latest" |
    grep '"tag_name":' |
    awk -F '["]' '{print $4}'
}

version_without_prefix_v(){
  local version=$1
  echo ${version#"v"}
}


zshenv(){
  echo "$HOME/.zshenv"
  # .zshenv 的使用还有问题,访问不到 uname
  # 无法把 toolsinit 都放进去
}

exportf(){
  local func_name=$1
  if [[ $SHELL == *bash* ]]; then
    export -f  $func_name
  else
    tee $(zshenv) <<EOF
$(declare -f $func_name) 
EOF
  fi
}

update(){
  git -C $HOME/sh pull
  $HOME/sh/win-git/move2zsh.sh
  zs
}
#$(exportf exist)
#会有问题

distro(){
  source /etc/os-release && echo "$ID"
}


#bindkey
###############################
exist(){
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
fi
if [[ "$(platform)" == "win" ]]; then 
  EDITOR=vim
  export EDITOR=vim
  code(){
    "C:/\Users\lynn\AppData\Local\Programs\Microsoft VS Code\Code.exe" $1
    "C:\Program Files\Microsoft VS Code\Code.exe" $1
    "Code.exe" $1
  }
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

# as start function
#  case $(platform) in
#    win) alias zd="explorer" ;;
#    linux) alias zd="xdg-open" ;;
#    macos) alias zd="open" ;;
#  esac
zluaload(){
  $(which _zlua)
  _zlua $1
}
zd(){
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
zdw(){
  #wsl
  zluaload $1
  /mnt/c/Windows/explorer.exe .
}
zcode(){
  zluaload $1
  code ./
}
alias chromium="chromium --no-sandbox"

zreload(){
  source $ZSH_HOME/win-git/toolsinit.sh
}
zedit(){
  $EDITOR $ZSH_HOME/win-git/toolsinit.sh
}
zgit(){
  #$EDITOR -C "gs"
  git -C $ZSH_HOME commit -a
}
zgitstatus(){
  #$EDITOR -C "gs"
  git -C $ZSH_HOME status
}
zgitaddall(){
  #$EDITOR -C "gs"
  git -C $ZSH_HOME add --all
}
zpush(){
  git -C $ZSH_HOME push
}
zfetch(){
  git -C $ZSH_HOME pull
}
ztermuxpaste(){
  echo $(termux-clipboard-get)
}
zxserver_scale(){
  local SCALE=$1
  export DISPLAY=:0.0
  export GDK_DPI_SCALING=$SCALE
}
zxserver(){
  local normal_scale=1
  zxserver_scale $normal_scale
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

wsl_ip(){
  cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }' |grep -oE "192.168.[0-9]{1,3}.[0-9]{1,3}" |grep -vE "255"
}

wsl_adb(){
  adb connect $(wsl_ip):5555
}

wsl_ssh(){
  ssh root@$(wsl_ip)
}

hotspot_ip(){
  #cat /etc/resolv.conf | grep 192.168.43 | awk '{ print $2}'
  if [[ $(exist ifconfig) == 1 ]]; then
    ifconfig |grep -oE "192.168.[0-9]{1,3}.[0-9]{1,3}" |grep -vE "255"
  elif [[ $(exist ip) == 1 ]]; then
    ip address |grep -oE "192.168.[0-9]{1,3}.[0-9]{1,3}" |grep -vE "255"
  else
    hostname -I |grep -oE "192.168.[0-9]{1,3}.[0-9]{1,3}" |grep -vE "255"
  fi
}

ssh_hotspot(){
  ssh maru@$(hotspot_ip)
}

proxy_ip(){
  #export http_proxy=http://127.0.0.1:8087
  local IP=$1

  export http_proxy=http://$IP:10808
  export https_proxy=http://$IP:10808

  #export http_proxy=socks5://127.0.0.1:1080
  #export https_proxy=socks5://127.0.0.1:1080
  #export ALL_PROXY=socks5://127.0.0.1:1080
  #export all_proxy=socks5://127.0.0.1:1080


  git config --global http.proxy http://$IP:10808
  git config --global https.proxy https://$IP:10808

  #git config --global http.proxy socks5://127.0.0.1:1080
  #git config --global https.proxy socks5://127.0.0.1:1080

}

unproxy(){
  git config --global --unset http.proxy 
  git config --global --unset https.proxy
}

proxy(){
  local normal_IP=127.0.0.1
  proxy_ip $normal_IP 
}

proxyw(){
  local normal_IP=$(wsl_ip)
  proxy_ip $normal_IP
}

proxys(){
  echo $http_proxy
}
node_split(){
  node -e "console.log('$1'.split('$2')[$3])"
}

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache

alias armake="ARCH=arm64 make"

export HOMEBREW_NO_AUTO_UPDATE=true

realScriptPath(){
  local x=$1
  echo $(cd $(dirname $0);pwd)/$x

}

realScriptPathDir(){
  local x=$1
  echo $(cd $(dirname $0);pwd)

}
