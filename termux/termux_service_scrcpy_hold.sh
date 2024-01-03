# Setup sshd services
SCRIPT_NAME="scrcpy_hold"
mkdir -p $PREFIX/var/service/${SCRIPT_NAME}/log
tee $PREFIX/var/service/${SCRIPT_NAME}/run <<EOF
#!/bin/sh
exec $(cd "$(dirname "$0")";pwd)/server_${SCRIPT_NAME}.sh
EOF
chmod +x $PREFIX/var/service/${SCRIPT_NAME}/run
#	touch code-server/down
ln -sf $PREFIX/share/termux-services/svlogger $PREFIX/var/service/${SCRIPT_NAME}/log/run
# Setup shortcuts
mkdir -p ~/.shortcuts
tee ~/.shortcuts/${SCRIPT_NAME}.sh <<EOF
exec $(cd "$(dirname "$0")";pwd)/server_${SCRIPT_NAME}.sh
EOF
