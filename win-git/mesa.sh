#!/bin/bash
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=mesarc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

echo 'export MESA_LOADER_DRIVER_OVERRIDE=zink'>${TOOLSRC}
echo 'export GALLIUM_DRIVER=zink'>>${TOOLSRC}
echo 'export XDG_RUNTIME_DIR=/tmp'>>${TOOLSRC}

case $(arch) in 
  amd64) SOFT_ARCH=x64;;
  386) SOFT_ARCH=x86;;
  armhf) SOFT_ARCH=armv7l;;
  aarch64)
    mesa_url=https://raw.githubusercontent.com/sherylynn/fonts/main/mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb
    mesa_name="mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb"
    ;;
esac
$(cache_downloader $mesa_name $mesa_url)
sudo dpkg -i  $(cache_folder)/$mesa_name 
sudo apt install -f -y
#需要安装mesa后，调用termux下的命令就可以启动了
#termux 下 运行mesa.sh 再切换su 运行 mesa.sh
#并把/data/data/com.termux/files/usr/tmp/ 挂载 /tmp/

#echo 'export GALLIUM_DRIVER=virpipe' >${TOOLSRC}
#echo 'export MESA_GL_VERSION_OVERRIDE=4.0'>> ${TOOLSRC}
#echo 'export XDG_RUNTIME_DIR=/tmp'>>${TOOLSRC}
