#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=iBotPeaches
NAME=Apktool

TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

INSTALL_PATH=$HOME/tools
#沙雕的version是 v2.4.1 而不是2.4.1
fuck_SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
array_fuck_SOFT_VERSION=(${fuck_SOFT_VERSION//v/})
SOFT_VERSION=${array_fuck_SOFT_VERSION[@]}
echo $SOFT_VERSION
DEX_VERSION=2.0

PLATFORM=$(platform)
if [[ "$PLATFORM" == "macos" ]]; then
  PLATFORM=osx
elif [[ "$PLATFORM" == "win" ]];then
  PLATFORM=windows
elif [[ "$PLATFORM" == "linux" ]];then
  PLATFORM=linux
fi

BIN_FILE_NAME=apktool
if [[ ${PLATFORM} == windows ]]; then
  BIN_FILE_PACK=${BIN_FILE_NAME}.bat
else
  BIN_FILE_PACK=${BIN_FILE_NAME}
fi

LIBS_FILE_NAME=${BIN_FILE_NAME}_${SOFT_VERSION}
SOFT_FILE_PACK=${LIBS_FILE_NAME}.jar

DEX_FILE_NAME=dex2jar
DEX_FILE_PACK=${DEX_FILE_NAME}-${DEX_VERSION}.zip
DEX_HOME=$(install_path)/${DEX_FILE_NAME}
#--------------------------
# Install LIBS
#--------------------------

SOFT_URL=https://github.com/$AUTHOR/$NAME/releases/download/v${SOFT_VERSION}/${SOFT_FILE_PACK}

if [[ "$(${BIN_FILE_PACK} --version)" != *${SOFT_VERSION}* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)

  rm -rf ${SOFT_HOME} && \
  mkdir -p ${SOFT_HOME} && \
    cp $(cache_folder)/${SOFT_FILE_PACK}  ${SOFT_HOME}/${BIN_FILE_NAME}.jar 
fi

if [ ! -f "${BIN_FILE_PACK}" ]; then
  echo https://raw.githubusercontent.com/$AUTHOR/$NAME/master/scripts/${PLATFORM}/${BIN_FILE_PACK}
  curl -o ${BIN_FILE_PACK} -L https://raw.githubusercontent.com/$AUTHOR/$NAME/master/scripts/${PLATFORM}/${BIN_FILE_PACK}
fi

mv ${BIN_FILE_PACK} $SOFT_HOME/${BIN_FILE_PACK}
if ! command -v d2j-dex2jar && ! command -v d2j-dex2jar.bat ;then
  if [ ! -f "${DEX_FILE_PACK}" ]; then
    curl -o ${DEX_FILE_PACK} -L https://sourceforge.net/projects/dex2jar/files/${DEX_FILE_PACK}/download
  fi

  if [ ! -d "${DEX_FILE_NAME}" ]; then
      #unzip -q ${DEX_FILE_PACK} -d ${DEX_FILE_NAME}
      unzip -q ${DEX_FILE_PACK}
      mv ${DEX_FILE_NAME}-${DEX_VERSION} ${DEX_FILE_NAME}
  fi
  rm -rf ${DEX_HOME} && \
  mv ${DEX_FILE_NAME} ${DEX_HOME} && \
  rm -rf ${DEX_FILE_PACK}
fi
#--------------------------

echo "export PATH=$SOFT_HOME:"'$PATH'> ${TOOLSRC}
echo "export PATH=$DEX_HOME:"'$PATH'>>${TOOLSRC}

#https://github.com/iBotPeaches/Apktool/releases/download/v2.4.1/apktool_2.4.1.jar
#https://github.com/iBotPeaches/Apktool/releases/download/v2.4.1/apktool_v2.4.1.jar