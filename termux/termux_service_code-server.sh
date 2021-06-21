# Setup sshd services
	mkdir -p $PREFIX/var/service
	cd $PREFIX/var/service
	mkdir -p code/log
	echo '#!/bin/sh' > code/run
	echo 'exec $PREFIX/../home/sh/termux/server_code-server.sh' >> code/run
	chmod +x code/run
	touch code/down
	ln -sf $PREFIX/share/termux-services/svlogger code/log/run
# Setup shortcuts
mkdir -p ~/.shortcuts
echo 'exec $PREFIX/../home/sh/termux/server_code-server.sh' > ~/.shortcuts/code_server.sh
