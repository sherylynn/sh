# script name
SCRIPT_NAME=ollama
# Setup sshd services
mkdir -p $PREFIX/var/service
cd $PREFIX/var/service
mkdir -p ${SCRIPT_NAME}/log
echo '#!/bin/sh' >${SCRIPT_NAME}/run
echo 'exec $PREFIX/../home/sh/termux/server_'${SCRIPT_NAME}'.sh' >>${SCRIPT_NAME}/run
chmod +x ${SCRIPT_NAME}/run
#	touch ${SCRIPT_NAME}/down
#	if touch will sv-down ${SCRIPT_NAME}
ln -sf $PREFIX/share/termux-services/svlogger ${SCRIPT_NAME}/log/run
# Setup shortcuts
mkdir -p ~/.shortcuts
echo 'exec $PREFIX/../home/sh/termux/server_'${SCRIPT_NAME}'.sh' >~/.shortcuts/${SCRIPT_NAME}.sh
