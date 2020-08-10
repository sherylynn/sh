echo 需要在管理员权限下打开msys2后再运行
curl -LO "https://raw.githubusercontent.com/rkitover/windows-alt-sshd-msys2/master/msys2-alt-sshd-setup.sh"
bash msys2-alt-sshd-setup.sh
<< '.ssh/config'
Host mingw64
  HostName localhost
  Port 2222
  RequestTTY yes
  # 本地可以不需要zsh -l
  RemoteCommand MSYSTEM=MINGW64
Host office
  HostName pi.sherylynn.win
  Port 2222
  RequestTTY yes
  # 远程windows 需要有zsh -l
  RemoteCommand MSYSTEM=MINGW64 zsh -l
  #  RemoteCommand MSYSTEM=MINGW64 bash -l
  #  RemoteCommand MSYSTEM=MINGW64 zsh -
.ssh/config