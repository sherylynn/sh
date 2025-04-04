#!/bin/bash
. $(dirname "$0")/toolsinit.sh
#SOFT_VERSION=25.3_1
NAME=emacs
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=29.4
SOFT_ARCH=x86_64
OS=windows
cd ~
#--------------------------------------
#安装 emacs
#--------------------------------------
if [[ $(platform) == *win* ]]; then
	PLATFORM=windows
	case $(arch) in
	amd64) SOFT_ARCH=x86_64 ;;
	386) SOFT_ARCH=i686 ;;
	esac

	SOFT_FILE_NAME=${NAME}-${SOFT_VERSION}-${SOFT_ARCH}
	SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
	# init pwd
	cd $HOME

	SOFT_URL=http://mirrors.nju.edu.cn/gnu/${NAME}/${PLATFORM}/${NAME}-$(echo ${SOFT_VERSION} | cut -d '.' -f 1)/${SOFT_FILE_PACK}
	#if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
	if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
		$(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
		$(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)

		rm -rf ${SOFT_HOME} &&
			mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
	fi
	#--------------new .toolsrc-----------------------
	SOFT_ROOT=${SOFT_HOME}/bin
	export PATH=$PATH:${SOFT_ROOT}
	echo "set HOME=$(cygpath $HOME -d)" >${SOFT_ROOT}/emacs_win.cmd
	echo "emacs" >>${SOFT_ROOT}emacs_win.cmd

	echo 'export PATH=$PATH:'${SOFT_ROOT} >${TOOLSRC}
fi

if [[ $(platform) == *appimage* ]]; then
	## diffcult to find lib to compile
	##  sudo apt install emacs-gtk librime-dev fd-find ripgrep -y
	##  sudo apt install cmake libtool-bin libvterm-dev -y
	##  sudo apt install libxpm-dev libgtk-3-dev build-essential libjpeg-dev libtiff-dev libgif-dev -y

	case $(arch) in
	amd64) SOFT_ARCH=x86_64 ;;
	386) SOFT_ARCH=i686 ;;
	esac
	SOFT_FILE_NAME=Emacs-${SOFT_VERSION}.glibc2.16-${SOFT_ARCH}
	SOFT_FILE_PACK=$SOFT_FILE_NAME.AppImage
	# init pwd
	cd $HOME

	SOFT_URL=https://github.com/probonopd/Emacs.AppImage/releases/download/continuous/${SOFT_FILE_PACK}
	if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
		$(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
		## no need to extract
		##chmod 777 $(cache_folder)/$SOFT_FILE_PACK
		##$(cache_folder)/$SOFT_FILE_PACK --appimage-extract
		##rm -rf ${SOFT_HOME}
		##mv squashfs-root ${SOFT_HOME}
		##cp ${SOFT_HOME}/AppRun ${SOFT_HOME}/emacs
		mkdir -p ${SOFT_HOME}
		cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/emacs
		chmod 777 ${SOFT_HOME}/emacs
	fi
	#--------------new .toolsrc-----------------------
	SOFT_ROOT=${SOFT_HOME}
	export PATH=$PATH:${SOFT_ROOT}
	echo 'export PATH=$PATH:'${SOFT_ROOT} >${TOOLSRC}
fi

if [[ $(platform) == *linux* ]]; then
	## diffcult to find lib to compile
	#开始使用 pyim，不用 rime 了
        #还是 rime 方便
	sudo apt install libgccjit0 librime-dev fd-find ripgrep -y
	#sudo apt install libgccjit0 fd-find ripgrep -y
	sudo apt install libvterm-dev -y
	sudo apt install libgccjit-12-dev -y
	sudo apt install libgccjit-10-dev -y
	sudo apt install libgccjit-8-dev -y
	sudo apt build-dep emacs -y
	##  sudo apt install cmake libtool-bin libvterm-dev -y
	##  sudo apt install libxpm-dev libgtk-3-dev build-essential libjpeg-dev libtiff-dev libgif-dev -y

	case $(arch) in
	amd64) SOFT_ARCH=x86_64 ;;
	386) SOFT_ARCH=i686 ;;
	esac
	SOFT_FILE_NAME=${NAME}-${SOFT_VERSION}
	SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)

	# init pwd
	cd $HOME
	##SOFT_URL=https://github.com/emacs-mirror/emacs/archive/refs/tags/emacs-$SOFT_VERSION.tar.gz

	#if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
	##$(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
	##$(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
	cd $(install_path)
	rm -rf emacs
	git clone -b emacs-${SOFT_VERSION} --depth 1 https://github.com/emacs-mirror/emacs.git
	#cd ${SOFT_HOME}
	#git checkout tags/${SOFT_VERSION}
	##rm -rf ${SOFT_HOME} && \
	##  mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
	#fi
	#--------------new .toolsrc-----------------------
	##SOFT_ROOT=${SOFT_HOME}/${NAME}-${NAME}-${SOFT_VERSION}
	##cd $SOFT_ROOT
	cd ${SOFT_HOME}
	./autogen.sh
	./configure --with-x --with-native-compilation --with-tree-sitter --with-modules
	make -j$(nproc)
	sudo make install
	export PATH=$PATH:${SOFT_ROOT}
	echo 'export PATH=$PATH:'${SOFT_ROOT} >${TOOLSRC}
fi
#--------------new .toolsrc-----------------------
#windows 下和 linux 下的不同
#windows 下还需要增加一个 HOME的环境变量去系统
