#麒麟系统的安全管理可以在设置中心的安全处关闭
#设置-安全中心-应用保护-应用程序执行控制-关闭
#可以命令行关闭
getstatus

sudo setstatus -f exectl off
# sudo setstatus -f exectl on

# 阻止奇安信浏览器更新，因为使用的是特殊版本
sudo apt-mark hold qaxbrowser-safe-stable

#install tools
sudo apt install zsh sshpass scrcpy firefox-esr -y

#init
#git clone https://github.com/sherylynn/sh
../win-git/move2zsh.sh 
