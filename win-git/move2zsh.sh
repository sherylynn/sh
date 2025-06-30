#!/bin/bash
. $(dirname "$0")/toolsinit.sh
echo $(bash_file)
if [[ ! -f $(alltoolsrc_file) ]]; then
  cat $(bash_file) | grep test >$(alltoolsrc_file)
fi
if [[ "$(cat $(bash_file))" != *zsh* ]]; then
  echo "not zsh"
  #echo zsh >> $(bash_file)
fi
#set default plugin manager to antigen
#ZSH_PLUG=antigen
ZSH_PLUG=zplug
if [[ $1 == zplug ]]; then
  ZSH_PLUG=zplug
elif [[ $1 == antigen ]]; then
  ZSH_PLUG=antigen
elif [[ $1 == help ]]; then
  echo "+++++++++++++++++++++++"
  echo "set ZSH_PLUG to antigen"
  ZSH_PLUG=antigen
else
  #ZSH_PLUG=antigen
  ZSH_PLUG=zplug
fi

if [[ "$ZSH_PLUG" == antigen ]]; then
  # load antigen
  ANTIGENRC_NAME=antigenrc
  ANTIGENRC=$(toolsRC $ANTIGENRC_NAME)
  ADOTDIR=$(install_path)/antigen
  git clone https://github.com/zsh-users/antigen $ADOTDIR
  echo export ADOTDIR=$ADOTDIR >$ANTIGENRC
  echo source $ADOTDIR/antigen.zsh >>$ANTIGENRC
elif [[ "$ZSH_PLUG" == zplug ]]; then
  # load zplug
  ZPLUG_HOME=$(install_path)/zplug
  export ZPLUG_HOME=$ZPLUG_HOME
  git clone https://github.com/zplug/zplug $ZPLUG_HOME
  ZPLUGRC_NAME=zplugrc
  ZPLUGRC=$(toolsRC $ZPLUGRC_NAME)
  echo export ZPLUG_HOME=$ZPLUG_HOME >$ZPLUGRC
  echo source $ZPLUG_HOME/init.zsh >>$ZPLUGRC
fi
# load myzshrc
TOOLSRC_NAME=myzshrc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)

tee $TOOLSRC <<EOF
if [ -n "\$BASH_VERSION" ]; then
    export PS1='\[\e[38;5;135m\]\u\[\e[0m\]@\[\e[38;5;166m\]\h\[\e[0m\] \[\e[38;5;118m\]\w\[\e[0m\] \$ '
else
    if [ "\$UID" -eq 0 ]; then
        export PROMPT="%F{135}%n%f@%F{166}%m%f %F{118}%~%f %# "
    else
        export PROMPT="%F{135}%n%f@%F{166}%m%f %F{118}%~%f \$ "
    fi
fi
ZSH_PLUG=$ZSH_PLUG
if [[ \$ZSH_PLUG == antigen ]]; then
  antigen bundle Vifon/deer
  #antigen bundle skywind3000/z.lua
  #antigen bundle zdharma/fast-syntax-highlighting
  antigen bundle z-shell/F-Sy-H --branch=main
  #antigen bundle sherylynn/fast-syntax-highlighting
  antigen bundle zsh-users/zsh-autosuggestions
  antigen apply
  autoload -U deer
  zle -N deer
  bindkey '\ev' deer
elif [[ \$ZSH_PLUG == zplug ]]; then
  source $ZPLUG_HOME/init.zsh
  zplug "vifon/deer", use:deer
  #zplug skywind3000/z.lua
  zplug zdharma/fast-syntax-highlighting
  #zplug sherylynn/fast-syntax-highlighting
  zle -N deer
  bindkey '\ek' deer
  zplug load
fi
bindkey -e
#方法一 autoload 加载后执行，无法 script 里调用 toolsinit.sh 内部函数，但是 script 可以手动呼唤 toolsinit.sh
#fpath+=$(
  cd "$(dirname "$0")"
  pwd
)
#autoload -U $(
  cd "$(dirname "$0")"
  pwd
)/toolsinit.sh
#toolsinit.sh
#直接执行 理同方法一，但 script 必须手动指定 路径来 source toolsinit.sh
#. $(
  cd "$(dirname "$0")"
  pwd
)/toolsinit.sh
#方法三 写入 .zshenv [需要看 uname 路径]
#方法三 写入 .zshenv [需要看 uname 路径]
#. $(
  cd "$(dirname "$0")"
  pwd
)/proxy.sh
setopt no_nomatch
#autoload -U compinit
#compinit -D
#ZSH_DISABLE_COMPFIX=true
EOF
echo ".  $(
  cd "$(dirname "$0")"
  pwd
)/toolsinit.sh " >$(zshenv)
if [[ $syntax ]]; then
  cd ~
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
  echo "source ~/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >>~/.zshrc
fi
cd ~
#compaudit | xargs chown -R "$(whoami)"
#compaudit | xargs chmod -R go-w
if [[ $(platform) == *macos* ]]; then
  brew install wget curl
fi
