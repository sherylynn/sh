#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=clash
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

SOFT_VERSION=0.16.0
SOFT_ARCH=amd64
Server=n
Client=n
Just_Install=n
#SOFT_ARCH=arm
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
if [[ "$PLATFORM" == "macos" ]]; then
  PLATFORM=darwin
elif [[ "$PLATFORM" == "win" ]];then
  PLATFORM=windows
elif [[ "$PLATFORM" == "linux" ]];then
  PLATFORM=linux
fi

case $(arch) in 
  amd64) SOFT_ARCH=amd64;;
  386) SOFT_ARCH=386;;
  armhf) SOFT_ARCH=armv7;;
  aarch64) SOFT_ARCH=armv8;;
esac

while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      SOFT_VERSION="$OPTARG";;
    a)
      SOFT_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

SOFT_FILE_NAME=${NAME}-${PLATFORM}-${SOFT_ARCH}-v${SOFT_VERSION}
SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME notar)
COMMAND_NAME=$SOFT_FILE_NAME
# init pwd
cd $HOME
SOFT_URL=https://github.com/Dreamacro/${NAME}/releases/download/v${SOFT_VERSION}/${SOFT_FILE_PACK}

if [[ "$(${NAME} -v)" != *${SOFT_VERSION}* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
  
  rm -rf ${SOFT_HOME} && \
    mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME} 
fi

SOFT_ROOT=${SOFT_HOME}/${SOFT_FILE_NAME}
if [[ ${PLATFORM} == linux ]]; then
  if [ ! -d "/etc/${NAME}" ]; then
  sudo mkdir /etc/${NAME}
  fi
  sudo ln -sf ~/config.yaml /etc/${NAME}/config.yaml
  chmod 777 ${SOFT_ROOT}/${COMMAND_NAME}
  sudo ln -sf ${SOFT_ROOT}/${COMMAND_NAME} /usr/local/bin/${NAME}
  sudo tee /etc/systemd/system/${NAME}.service <<-EOF
[Unit]
Description=${NAME} Service
After=NetworkManager-wait-online.service network.target network-online.target 
Wants=NetworkManager-wait-online.service network.target network-online.target 

[Service]
Type=simple
ExecStart=/usr/local/bin/${NAME} -d /etc/${NAME}
Restart=on-abnormal
[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable ${NAME}.service
  sudo systemctl start ${NAME}.service
fi
