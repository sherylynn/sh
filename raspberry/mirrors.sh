sudo apt install curl gnupg -y
curl -fsSL http://mirrors.ustc.edu.cn/archive.raspberrypi.org/debian/raspberrypi.gpg.key | sudo apt-key add -
curl -fsSL http://mirrors.aliyun.com/raspbian/raspbian.public.key | sudo apt-key add -
#sudo cp ~/sh/raspberry/sources.list /etc/apt/
sudo cp ~/sh/raspberry/sources.list /etc/apt/sources.list.d/raspbian.list
sudo cp ~/sh/raspberry/raspi.list /etc/apt/sources.list.d/
sudo apt update
