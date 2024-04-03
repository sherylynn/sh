#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=wezterm
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
PLATFORM=$(platform)

tee ~/.wezterm.lua <<EOF
local wezterm = require 'wezterm'
local config={}

-- 单独的这个配置也可以用，也可以这样引用，其实还可以用module require的方式
dofile(wezterm.config_dir .. "/sh/win-git/wezterm.lua")(config)
return config
EOF

if [[ ${PLATFORM} == mac ]]; then
  #for brew
  brew tap wez/wezterm
  brew install --cask wez/wezterm/wezterm
elif [[ ${PLATFORM} == win ]]; then
  #for cygwin
  echo 'export TMUX_TMPDIR=~/.tmux/tmp' > ${TOOLSRC}
  export TMUX_TMPDIR=~/.tmux/tmp
  mkdir -p ~/.tmux/tmp
  chmod 777 -R ~/.tmux/tmp
  #for exfat cygwin
  echo "alias tmux='tmux -S ~/.tmsock new -ADsCyg'" >> ${TOOLSRC}
fi
