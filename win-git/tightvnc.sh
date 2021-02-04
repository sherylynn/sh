#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=vnc
USER=$(whoami)
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

REVOLUTION_WIDTH=1366
REVOLUTION_HIGH=768
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
Type=forking
User=$(whoami)
Group=$(whoami)
WorkingDirectory=/home/$(whoami)
PIDFile=/home/$(whoami)/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 16 -dpi 75  -geometry ${REVOLUTION_WIDTH}x${REVOLUTION_HIGH} :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target

EOF
sudo systemctl daemon-reload
sudo systemctl enable ${NAME}.service
sudo systemctl restart ${NAME}.service
