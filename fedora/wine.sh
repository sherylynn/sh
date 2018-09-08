lynn=$HOME
INSTALL_PATH=$HOME/tools
sudo yum install wine winetricks -y
cd $INSTALL_PATH
git clone https://github.com/hillwoodroc/winetricks-zh.git
sudo ln -s -f $INSTALL_PATH/winetricks-zh/winetricks-zh /usr/bin/winetricks-zh
