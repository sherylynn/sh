#!/bin/bash
. $(dirname "$0")/toolsinit.sh
echo $(bash_file)
if [[ ! -f $(alltoolsrc_file) ]];then
  cat $(bash_file) |grep test >$(alltoolsrc_file)
fi
if [[ "$(cat $(bash_file))" != *zsh* ]]; then
  echo "not zsh"
  #echo zsh >> $(bash_file)
fi
ANTIGENRC_NAME=antigen.zsh
ANTIGENRC=$(toolsRC $ANTIGENRC_NAME)
TOOLSRC_NAME=myzshrc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)

curl -L git.io/antigen > $ANTIGENRC

tee $TOOLSRC <<-'EOF'
if [ -n "$BASH_VERSION" ]; then
    export PS1='\[\e[38;5;135m\]\u\[\e[0m\]@\[\e[38;5;166m\]\h\[\e[0m\] \[\e[38;5;118m\]\w\[\e[0m\] \$ '
else
    if [ "$UID" -eq 0 ]; then
        export PROMPT="%F{135}%n%f@%F{166}%m%f %F{118}%~%f %# "
    else
        export PROMPT="%F{135}%n%f@%F{166}%m%f %F{118}%~%f \$ "
    fi
fi
antigen bundle Vifon/deer
antigen bundle zdharma/fast-syntax-highlighting
antigen apply
EOF
if [[ $syntax ]];then
cd ~
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
  echo "source ~/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
fi
