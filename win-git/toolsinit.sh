#!/bin/zsh
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
if [[ $PREFIX == *termux*  ]]; then
  alias uname=$PREFIX/bin/uname
else
  alias uname=/usr/bin/uname #for msys2 which can't found uname in .zshenv
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
fi

platform(){
  local PLATFORM=win
  if [[ "$(uname)" == *MINGW* ]]; then
    BASH_FILE=~/.bash_profile
    PLATFORM=win
  elif [[ "$(uname)" == *Linux* ]]; then
    BASH_FILE=~/.bashrc
    PLATFORM=linux
  elif [[ "$(uname)" == *Darwin* ]]; then
    BASH_FILE=~/.bash_profile
    PLATFORM=macos
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

cache_unpacker(){
  local soft_file_pack=$1
  local soft_file_name=$2
  cd $(cache_folder)
  if [ ! -d "${soft_file_name}" ]; then
    if [[ $(platform) == win ]]; then
      unzip -q ${soft_file_pack} -d ${soft_file_name}
    elif [[ ${soft_file_pack} != *tar* ]]; then
      mkdir -p ${soft_file_name}/${soft_file_name}
      gunzip -c ${soft_file_pack} > ${soft_file_name}/${soft_file_name}/${soft_file_name}
    else
      mkdir ${soft_file_name}
      tar -xzf ${soft_file_pack} -C ${soft_file_name}
    fi
  fi

}

soft_file_pack(){
  local soft_file_name=$1
  local notar=$2

  if [[ $(platform) == win ]]; then
    echo ${soft_file_name}.zip
  elif [[ $notar == notar ]]; then
    echo ${soft_file_name}.gz
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

exist(){
  #autoload -X
  local COMMAND=$1
  if command -v $1 >/dev/null 2>&1; then
    echo 1
  else
    echo 0
  fi
}

zshenv(){
  echo "$HOME/.zshenv"
  # .zshenv 的使用还有问题,访问不到uname
  # 无法把toolsinit都放进去
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
if [[ "$(platform)" == "win" ]]; then 
  EDITOR=vim
  export EDITOR=vim
else
  EDITOR=nvim
  export EDITOR=nvim
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
    win) start . ;;
    linux) xdg-open .;;
    macos) open ./ ;;
  esac
}
zcode(){
  zluaload $1
  code ./
}


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
alias zc="zcode"
alias zg="zgit"
alias zgs="zgitstatus"
alias zga="zgitaddall"
alias zp="zpush"
alias zf="zfetch"
alias zr="zreload"
alias ze="zedit"
#bindkey -e

proxy(){
  #export http_proxy=http://127.0.0.1:8087
  #export http_proxy=http://127.0.0.1:10808
  #export https_proxy=http://127.0.0.1:10808

  export http_proxy=socks5://127.0.0.1:1080
  export ALL_PROXY=socks5://127.0.0.1:1080


  #git config --global https.proxy http://127.0.0.1:10808
  #git config --global https.proxy https://127.0.0.1:10808

  git config --global http.proxy socks5://127.0.0.1:1080
    git config --global https.proxy socks5://127.0.0.1:1080

}
