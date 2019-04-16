#!/bin/bash
INSTALL_PATH=$HOME/tools
FRP_HOME=$INSTALL_PATH/frp
FRP_VERSION=0.24.1
FRP_ARCH=amd64
Server=n
Client=n
Just_Install=n
#FRP_ARCH=arm
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=windows
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=darwin
fi

if [[ "$(uname -a)" == *x86_64* ]]; then
  FRP_ARCH=amd64
elif [[ "$(uname -a)" == *i686* ]]; then
  FRP_ARCH=386
elif [[ "$(uname -a)" == *armv8l* ]]; then
  case $(getconf LONG_BIT) in 
    32) FRP_ARCH=arm;;
    64) FRP_ARCH=arm64;;
  esac
elif [[ "$(uname -a)" == *aarch64* ]]; then
  FRP_ARCH=arm64
elif [[ "$(uname -a)" == *armv7l* ]]; then
  FRP_ARCH=arm
fi
while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      FRP_VERSION="$OPTARG";;
    a)
      FRP_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

FRP_FILE_NAME=frp_${FRP_VERSION}_${PLATFORM}_${FRP_ARCH}
if [[ ${PLATFORM} == win ]]; then
  FRP_FILE_PACK=${FRP_FILE_NAME}.zip
else
  FRP_FILE_PACK=${FRP_FILE_NAME}.tar.gz
fi
# init pwd
cd $HOME
if [[ "$(frpc --version)" != *${FRP_VERSION}* ]]; then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${FRP_FILE_PACK}" ]; then
    Download_URL=https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_FILE_PACK}
    echo ${Download_URL}
    curl -o ${FRP_FILE_PACK} -L ${Download_URL}
  fi
  
  if [ ! -d "${FRP_FILE_NAME}" ]; then
    if [ ${PLATFORM} == win ]; then
      unzip -q ${FRP_FILE_PACK} -d ${FRP_FILE_NAME}
    else
      mkdir ${FRP_FILE_NAME}
      tar -xzf ${FRP_FILE_PACK} -C ${FRP_FILE_NAME}
    fi
  fi
  rm -rf ${FRP_HOME} && \
  mv ${FRP_FILE_NAME} ${FRP_HOME} && \
  rm -rf ${FRP_FILE_PACK}
fi
FRP_ROOT=${FRP_HOME}/${FRP_FILE_NAME}
if [[ ${PLATFORM} == linux ]]; then
  if [ ! -d "/etc/frp" ]; then
  sudo mkdir /etc/frp
  fi
  sudo ln -sf ${FRP_ROOT}/frps.ini /etc/frp/frps.ini
  sudo ln -sf ${FRP_ROOT}/frpc.ini /etc/frp/frpc.ini

  sudo ln -sf ${FRP_ROOT}/frps /usr/local/bin/frps
  sudo ln -sf ${FRP_ROOT}/frpc /usr/local/bin/frpc
  if [ ${Server} = "y" ]; then  
  sudo tee /etc/systemd/system/frps.service <<-'EOF'
[Unit]
Description=frps Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.ini
Restart=on-abnormal
[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable frps.service
  sudo systemctl start frps.service
  fi  

  if [ ${Client} = "y" ]; then 
  sudo tee /etc/systemd/system/frpc.service <<-'EOF'
[Unit]
Description=frpc Service
After=NetworkManager-wait-online.service network.target network-online.target 
Wants=NetworkManager-wait-online.service network.target network-online.target 

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.ini
Restart=on-abnormal
[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable frpc.service
  sudo systemctl start frpc.service
  fi
fi
