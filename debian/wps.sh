#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

#话说链接不带参数会被禁止，感觉不好用
#wps_url=https://wps-linux-personal.wpscdn.cn/wps/download/ep/Linux2019/11719/wps-office_11.1.0.11719_arm64.deb?t=1718868135&k=d1c05d330d0cb18c0bb9616b6402e2c9
wps_url=https://github.com/sherylynn/fonts/releases/download/wps/wps-office_11.1.0.11719_arm64.deb
wps_name="wps-office_11.1.0.11719_arm64.deb"
$(cache_downloader $wps_name $wps_url)
sudo dpkg -i  $(cache_folder)/$wps_name 
sudo apt install -f -y
