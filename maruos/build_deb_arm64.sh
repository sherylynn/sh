#image cache is in 
#/var/cache/lxc/download/debian

# if error should delete this
cd ~
git clone https://github.com/maruos/blueprints
cd blueprints

sudo apt-get update && apt-get install -y \
    binfmt-support \
    debootstrap \
    fakeroot \
    git \
    lxc \
    make \
    bash \
    qemu-user-static \
    ubuntu-archive-keyring \

sudo ./build.sh -b debian -n deb -- -r buster -a arm64 --minimal
