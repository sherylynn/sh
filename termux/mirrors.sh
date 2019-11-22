#sed -i 's,https://termux.net,https://mirrors.ustc.edu.cn/termux,' $PREFIX/etc/apt/sources.list
sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux stable main@' $PREFIX/etc/apt/sources.list
apt update && apt upgrade
