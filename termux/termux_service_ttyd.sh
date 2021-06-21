# Setup sshd services
	mkdir -p $PREFIX/var/service
	cd $PREFIX/var/service
	mkdir -p ttyd/log
	echo '#!/bin/sh' > ttyd/run
	echo 'exec $PREFIX/../home/sh/termux/server_ttyd.sh' >> ttyd/run
	chmod +x ttyd/run
	touch ttyd/down
	ln -sf $PREFIX/share/termux-services/svlogger ttyd/log/run
