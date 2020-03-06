#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=Maximus5
NAME=ConEmu

TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

INSTALL_PATH=$HOME/tools
#沙雕的version是 v2.4.1 而不是2.4.1
fuck_SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
array_fuck_SOFT_VERSION=(${fuck_SOFT_VERSION//v/})
point_SOFT_VERSION=${array_fuck_SOFT_VERSION[@]}
array_point_SOFT_VERSION=(${point_SOFT_VERSION//./})
SOFT_VERSION=${array_point_SOFT_VERSION[@]}
echo $SOFT_VERSION

PLATFORM=$(platform)
if [[ "$PLATFORM" == "macos" ]]; then
  PLATFORM=osx
elif [[ "$PLATFORM" == "win" ]];then
  PLATFORM=windows
elif [[ "$PLATFORM" == "linux" ]];then
  PLATFORM=linux
fi


#--------------------------
SOFT_FILE_PACK=${NAME}Setup.${SOFT_VERSION}.exe
SOFT_URL=https://github.com/$AUTHOR/$NAME/releases/download/${fuck_SOFT_VERSION}/${SOFT_FILE_PACK}
#--------------------------
$(cache_downloader $SOFT_FILE_PACK $SOFT_URL)


start $(cache_folder)/${SOFT_FILE_PACK}
#--------------------------


