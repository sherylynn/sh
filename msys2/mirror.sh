#!/bin/bash
read -p "should we use ustc mirror or tuna mirror ? 1 or 2 : " RESTART
case $RESTART in
  1) mirror=http://mirrors.ustc.edu.cn/;;
  2) mirror=http://mirrors.tuna.tsinghua.edu.cn/;;
esac
file1="/etc/pacman.d/mirrorlist.mingw32"
file2="/etc/pacman.d/mirrorlist.mingw64"
file3="/etc/pacman.d/mirrorlist.msys"
str1="Server = $mirror/msys2/mingw/i686"
str2="Server = $mirror/msys2/mingw/x86_64"
str3="Server = $mirror/msys2/msys/"'$arch'
[[ $(sed -n '1p' ${file1}) != ${str1} ]] && sed -i "1i${str1}" ${file1}
[[ $(sed -n '1p' ${file2}) != ${str2} ]] && sed -i "1i${str2}" ${file2}
[[ $(sed -n '1p' ${file3}) != ${str3} ]] && sed -i "1i${str3}" ${file3}
