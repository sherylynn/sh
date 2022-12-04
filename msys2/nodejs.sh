shopt expand_aliases
#不知道为啥又不生效了alias
#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
#SOFT_VERSION=25.3_1
NAME=node
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
MODULE_PATH=/mingw64/bin/lib
SOFT_VERSION=28.1
SOFT_ARCH=x86_64
OS=windows
if [[ $(platform) == *win* ]]; then
  pacman -Syu mingw64/mingw-w64-x86_64-nodejs
  alias npm="node /mingw64/lib/node_modules/npm/bin/npm-cli.js"
  export PATH=$PATH:/mingw64/bin/lib
  which npm
  node /mingw64/lib/node_modules/npm/bin/npm-cli.js i yrm yarn http-server npm --registry=https://registry.npmmirror.com --location=global
  yrm add newtaobao https://registry.npmmirror.com
  yrm use newtaobao
  echo "con.nvim:registry=https://registry.npmmirror.com">>~/.npmrc
  echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}
  echo 'alias npm="node /mingw64/lib/node_modules/npm/bin/npm-cli.js"' >> ${TOOLSRC}
  echo 'export PATH=$PATH:'${MODULE_PATH}>>${TOOLSRC}
fi
#--------------new .toolsrc-----------------------
#windows下和linux下的不同
#windows 下还需要增加一个HOME的环境变量去系统
