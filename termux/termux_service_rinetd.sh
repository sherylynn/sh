# Setup sshd services
	mkdir -p $PREFIX/var/service
	cd $PREFIX/var/service
	mkdir -p rinetd/log
	echo '#!/bin/sh' > rinetd/run
	echo 'exec $PREFIX/../home/sh/termux/server_rinetd.sh' >> code/run
	chmod +x rinetd/run
	touch rinetd/down
	ln -sf $PREFIX/share/termux-services/svlogger rinetd/log/run
# Setup shortcuts
mkdir -p ~/.shortcuts
echo 'exec $PREFIX/../home/sh/termux/server_rinetd.sh' > ~/.shortcuts/port_forward.sh
