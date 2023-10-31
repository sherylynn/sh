#不再采用npm方式安装，采用termux自带方式安装
#pkg install build-essential python3 pkg-config
#npm i -g code-server
pkg install tur-repo
pkg install code-server
./termux_service_code-server.sh

#enable code in termux_service 
#sv-enable code
