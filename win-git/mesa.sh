#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=mesa
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

AUTHOR=lfdevs
NAME=mesa-for-android-container
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"

mkdir -p $SOFT_HOME

case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    if lscpu | grep -q "Oryon"; then
      echo "Oryon CPU detected. Installing specific Mesa drivers..."
      # Define files for Oryon
      if [[ $SOFT_VERSION == "turnip-"* ]]; then
        VERSION_PART="${SOFT_VERSION#turnip-}"
        MESA_TAG="mesa-${VERSION_PART}"
        TURNIP_TAG="${SOFT_VERSION}"

        URL1="https://github.com/${AUTHOR}/${NAME}/releases/download/${MESA_TAG}/mesa-for-android-container_${VERSION_PART}_debian_trixie_arm64.tar.gz"
        NAME1="mesa-for-android-container_${VERSION_PART}_debian_trixie_arm64.tar.gz"
        URL2="https://github.com/${AUTHOR}/${NAME}/releases/download/${TURNIP_TAG}/turnip_${VERSION_PART}_debian_trixie_arm64.tar.gz"
        NAME2="turnip_${VERSION_PART}_debian_trixie_arm64.tar.gz"
      else
        echo "Could not parse version from $SOFT_VERSION. Exiting."
        exit 1
      fi

      # Download and install first file
      # 下载驱动安装到我自己的目录
      $(cache_downloader "$NAME1" "$URL1")

      # Download and install second file
      $(cache_downloader "$NAME2" "$URL2")
      echo "Installing $NAME1..."
      echo "Installing $NAME2..."
      #如果删除驱动重新安装
      if [ "${INSTALL_TO_FOLDER}"]; then
        #先重新安装正版驱动
        filelist1=$(
          tar tf $NAME1 | grep -v '/$' | tr '\n' ' '
          echo
        )
        echo $filelist1
        filelist2=$(
          tar tf $NAME2 | grep -v '/$' | tr '\n' ' '
          echo
        )
        cd /
        rm -rf $filelist1 $filelist2
        sudo apt install --reinstall libegl-mesa0 libgbm1 libgl1-mesa-dri libglx-mesa0 mesa-libgallium mesa-vulkan-drivers -y
      else
        sudo tar -xvf "$(cache_folder)/$NAME1" -C /
        sudo tar -zxvf "$(cache_folder)/$NAME2" -C /
      fi
      echo "Oryon-specific drivers installed."

      sudo ldconfig
      exit 0 # Exit successfully after handling the special case
    elif lscpu | grep -q "骁龙865可以用"; then
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
