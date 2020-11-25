cd ~
git clone https://github.com/maruos/blueprints
cd blueprints
sudo apt install -y \
    binfmt-support \
    debootstrap \
    fakeroot \
    git \
    lxc \
    make \
    qemu-user-static \
    ubuntu-archive-keyring
sudo ./build.sh -b debian -n deb -- -r buster -a arm64 --minimal
