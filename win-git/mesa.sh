#!/bin/bash
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=mesarc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    if lscpu | grep -q "Oryon"; then
      echo "Oryon CPU detected. Installing specific Mesa drivers..."
      # Define files for Oryon
      #URL1="https://github.com/lfdevs/mesa-for-android-container/releases/download/turnip-26.1.0-devel-20260125/vulkan-freedreno-1-26.1.0-1-aarch64.pkg.tar.xz"
      #NAME1="vulkan-freedreno-1-26.1.0-1-aarch64.pkg.tar.xz"
      #URL1="https://github.com/lfdevs/mesa-for-android-container/releases/download/mesa-26.1.0-devel-20260125/mesa-for-android-container_26.1.0-devel-20260125_debian_trixie_arm64.tar.gz"
      URL1="https://github.com/lfdevs/mesa-for-android-container/releases/download/mesa-26.0.0-devel-20260116/mesa-for-android-container_26.0.0-devel-20260116_debian_trixie_arm64.tar.gz"
      NAME1="mesa-for-android-container_26.0.0-devel-20260116_debian_trixie_arm64.tar.gz"
      #NAME1="mesa-for-android-container_26.0.0-devel-20260116_debian_trixie_arm64.tar.gz"
      #URL2="https://github.com/lfdevs/mesa-for-android-container/releases/download/turnip-26.1.0-devel-20260125/turnip_26.1.0-devel-20260125_debian_trixie_arm64.tar.gz"
      URL2="https://github.com/lfdevs/mesa-for-android-container/releases/download/turnip-26.0.0-devel-20260116/turnip_26.0.0-devel-20260116_debian_trixie_arm64.tar.gz"
      #NAME2="turnip_26.1.0-devel-20260125_debian_trixie_arm64.tar.gz"
      NAME2="turnip_26.0.0-devel-20260116_debian_trixie_arm64.tar.gz"

      # Download and install first file
      $(cache_downloader "$NAME1" "$URL1")
      echo "Installing $NAME1..."
      #sudo tar -xvf "$(cache_folder)/$NAME1" -C /
      sudo tar -zxvf "$(cache_folder)/$NAME1" -C /

      # Download and install second file
      $(cache_downloader "$NAME2" "$URL2")
      echo "Installing $NAME2..."
      sudo tar -zxvf "$(cache_folder)/$NAME2" -C /

      echo "Oryon-specific drivers installed."

      sudo ldconfig
      exit 0 # Exit successfully after handling the special case
    else
      # Default aarch64 behavior (non-Oryon)
      echo 'export MESA_LOADER_DRIVER_OVERRIDE=zink' >${TOOLSRC}
      #echo 'export GALLIUM_DRIVER=zink'>>${TOOLSRC}
      echo 'export TU_DEBUG=noconform' >>${TOOLSRC}
      echo 'export XDG_RUNTIME_DIR=/tmp' >>${TOOLSRC}
      mesa_url="https://raw.githubusercontent.com/sherylynn/fonts/main/mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb"
      mesa_name="mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb"
      $(cache_downloader $mesa_name $mesa_url)
      sudo dpkg -i $(cache_folder)/$mesa_name
      sudo apt install -f -y
    fi
    ;;
esac
#需要安装mesa后，调用termux下的命令就可以启动了
#termux 下 运行mesa.sh 再切换su 运行 mesa.sh
#并把/data/data/com.termux/files/usr/tmp/ 挂载 /tmp/

#echo 'export GALLIUM_DRIVER=virpipe' >${TOOLSRC}
#echo 'export MESA_GL_VERSION_OVERRIDE=4.0'>> ${TOOLSRC}
#echo 'export XDG_RUNTIME_DIR=/tmp'>>${TOOLSRC}
