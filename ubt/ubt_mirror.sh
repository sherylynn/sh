#
sudo vi /etc/apt/sources.list +%s#archive.ubuntu.com#mirror.aliyun.com#g +wq!
sudo vi /etc/apt/sources.list +%s#security.ubuntu.com#mirror.aliyun.com#g +wq!
sudo apt update
