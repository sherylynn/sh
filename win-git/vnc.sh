#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=vnc
USER=$(whoami)
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

sudo apt install x11vnc -y
echo !!!!!!!!!!!!!!!!!!!!!!!
echo sudo x11vnc -storepasswd [PASSWORD] /etc/x11vnc.passwd
echo !!!!!!!!!!!!!!!!!!!!!!!
while getopts 'w:h:sc' OPT; do
  case $OPT in
    w)
      REVOLUTION_WIDTH="$OPTARG";;
    h)
      REVOLUTION_HIGH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

# init pwd
cd $HOME

sudo tee /etc/systemd/system/${NAME}.service <<-EOF
[Unit]
Description=${NAME} Service
After=syslog.target network.target

[Service]
Restart=always
# Replace this with x0vncserver from TigerVNC in Ubuntu 18.04.
# Set password by running `sudo x11vnc -storepasswd [PASSWORD] /etc/x11vnc.passwd`
ExecStart=/usr/bin/x11vnc -auth guess -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.passwd -rfbport 5900 -shared

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable ${NAME}.service
sudo systemctl restart ${NAME}.service
