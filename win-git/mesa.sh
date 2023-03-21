#!/bin/bash
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=mesarc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

echo 'export MESA_LOADER_DRIVER_OVERRIDE=zink'>${TOOLSRC}
echo 'export GALLIUM_DRIVER=zink'>>${TOOLSRC}
echo 'export XDG_RUNTIME_DIR=/tmp'>>${TOOLSRC}

#需要安装mesa后，调用termux下的命令就可以启动了

echo 'export GALLIUM_DRIVER=virpipe' >${TOOLSRC}
echo 'export MESA_GL_VERSION_OVERRIDE=4.0'>> ${TOOLSRC}
echo 'export XDG_RUNTIME_DIR=/tmp'>>${TOOLSRC}
