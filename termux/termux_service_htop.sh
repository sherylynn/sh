# Setup sshd services
	mkdir -p $PREFIX/var/service
	cd $PREFIX/var/service
	mkdir -p htop/log
	echo '#!/bin/sh' > htop/run
	echo 'exec $PREFIX/../home/sh/termux/server_htop.sh' >> htop/run
	chmod +x htop/run
	touch htop/down
	ln -sf $PREFIX/share/termux-services/svlogger htop/log/run
# Setup shortcuts
mkdir -p ~/.shortcuts
echo 'exec $PREFIX/../home/sh/termux/server_htop.sh' > ~/.shortcuts/htop.sh
