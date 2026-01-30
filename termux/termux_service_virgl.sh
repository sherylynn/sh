# script name
SCRIPT_NAME=virgl
if lscpu | grep -q "Oryon"; then
  echo "Oryon Use freedreno"
  # Remove virgl service if it exists
  if [ -d "$PREFIX/var/service/${SCRIPT_NAME}" ]; then
    rm -rf "$PREFIX/var/service/${SCRIPT_NAME}"
    echo "Removed existing virgl service for Oryon CPU."
  fi
  if [ -f "~/.shortcuts/${SCRIPT_NAME}.sh" ]; then
    rm -f "~/.shortcuts/${SCRIPT_NAME}.sh"
    echo "Removed existing virgl shortcut for Oryon CPU."
  fi
else
  # Setup services
  mkdir -p $PREFIX/var/service
  cd $PREFIX/var/service
  mkdir -p ${SCRIPT_NAME}/log
  echo '#!/bin/sh' >${SCRIPT_NAME}/run
  echo 'exec $PREFIX/../home/sh/termux/server_'${SCRIPT_NAME}'.sh' >>${SCRIPT_NAME}/run
  chmod +x ${SCRIPT_NAME}/run
  touch ${SCRIPT_NAME}/down
  ln -sf $PREFIX/share/termux-services/svlogger ${SCRIPT_NAME}/log/run
  # Setup shortcuts
  mkdir -p ~/.shortcuts
  echo 'exec $PREFIX/../home/sh/termux/server_'${SCRIPT_NAME}'.sh' >~/.shortcuts/${SCRIPT_NAME}.sh
fi
