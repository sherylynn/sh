@echo off
@echo 开始
start /min cmd /c docker-compose -f nextcloud_win.yml up -d
::docker-compose -f nextcloud_win.yml stop