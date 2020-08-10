echo 需要在管理员权限下打开msys2后再运行
curl -LO "https://raw.githubusercontent.com/rkitover/windows-alt-sshd-msys2/master/msys2-alt-sshd-setup.sh"
bash msys2-alt-sshd-setup.sh
#Host mingw64
#  HostName localhost
#  Port 2222
#  RequestTTY yes
#  RemoteCommand MSYSTEM=MINGW64 bash -l