pacman-key --init
pacman-key --populate archlinuxarm
#update /etc/pacman.d/mirrorslist add mirrors.ustc.edu.cn/archlinuxarm
pacman -Syu
pacman -S git vim htop --needed --noconfirm
