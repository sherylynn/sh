#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=box
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

# 确保软件主目录存在
mkdir -p "${SOFT_HOME}"

#--------------------------------------
# 安装 box64 和 box86
#--------------------------------------
if [[ $(platform) == *linux* ]]; then
    # Add armhf architecture and update
    sudo dpkg --add-architecture armhf
    sudo apt-get update
    
    # Install dependencies
    sudo apt-get install -y git build-essential cmake
    sudo apt-get install -y libc6:armhf gcc-arm-linux-gnueabihf

    # --- Install box64 ---
    cd "${SOFT_HOME}"
    git clone https://github.com/ptitSeb/box64.git
    cd box64
    mkdir -p build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX="${SOFT_HOME}/box64_inst" -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo
    make -j$(nproc)
    make install # No sudo, install to local prefix

    # --- Install box86 ---
    cd "${SOFT_HOME}"
    git clone https://github.com/ptitSeb/box86.git
    cd box86
    mkdir -p build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX="${SOFT_HOME}/box86_inst" -DARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo
    make -j$(nproc)
    make install # No sudo, install to local prefix

    # --- Handle binfmt registration ---
    # Copy the binfmt config files to the system directory
    sudo cp "${SOFT_HOME}/box64_inst/etc/binfmt.d/box64.conf" /etc/binfmt.d/
    sudo cp "${SOFT_HOME}/box86_inst/etc/binfmt.d/box86.conf" /etc/binfmt.d/
    # Update the path in the binfmt config files to point to our custom location
    sudo sed -i "s|/usr/local/bin/box64|${SOFT_HOME}/box64_inst/bin/box64|" /etc/binfmt.d/box64.conf
    sudo sed -i "s|/usr/local/bin/box86|${SOFT_HOME}/box86_inst/bin/box86|" /etc/binfmt.d/box86.conf
    sudo systemctl restart systemd-binfmt

    #--------------new .toolsrc-----------------------
    # 1. 检查 TOOLSRC 变量是否有效
    if [ -z "${TOOLSRC}" ]; then
        echo "Error: Could not determine the rc file path from toolsRC function. Aborting environment setup." >&2
        exit 1
    fi

    # 2. 确保 TOOLSRC 所在的目录存在
    TOOLSRC_DIR=$(dirname "${TOOLSRC}")
    mkdir -p "${TOOLSRC_DIR}"

    # 3. 现在可以安全地写入文件
    BOX64_ROOT=${SOFT_HOME}/box64_inst/bin
    BOX86_ROOT=${SOFT_HOME}/box86_inst/bin
    BOX86_LIB=${SOFT_HOME}/box86_inst/lib/box86-i386-linux-gnu
    BOX64_LIB=${SOFT_HOME}/box64_inst/lib/box64-x86_64-linux-gnu

    echo "export PATH=\$PATH:${BOX64_ROOT}:${BOX86_ROOT}" > "${TOOLSRC}"
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:${BOX64_LIB}:${BOX86_LIB}" >> "${TOOLSRC}"
fi
