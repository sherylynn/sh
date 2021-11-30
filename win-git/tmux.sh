#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=tmux
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
PLATFORM=$(platform)

sudo apt install tmux -y
echo "source-file ~/sh/win-git/tmux.conf" > ~/.tmux.conf
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

if [[ ${PLATFORM} == win ]]; then
  #for cygwin
  echo 'export TMUX_TMPDIR=~/.tmux/tmp' > ${TOOLSRC}
  export TMUX_TMPDIR=~/.tmux/tmp
  mkdir -p ~/.tmux/tmp
  chmod 777 -R ~/.tmux/tmp
  #for exfat cygwin
  echo "alias tmux='tmux -S ~/.tmsock new -ADsCyg'" >> ${TOOLSRC}
fi
