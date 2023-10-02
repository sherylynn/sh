cd ~
git clone -b openwrt-22.03 --single-branch https://github.com/openwrt/openwrt.git
sudo apt-get -y install build-essential asciidoc binutils bzip2 curl gawk gettext git libncurses5-dev libz-dev patch python3.5 python2.7 unzip zlib1g-dev lib32gcc1 libc6-dev-i386 subversion flex uglifyjs git-core gcc-multilib p7zip p7zip-full msmtp libssl-dev texinfo libglib2.0-dev xmlto qemu-utils upx libelf-dev autoconf automake libtool autopoint device-tree-compiler g++-multilib antlr3 gperf
# Essential prerequisites
sudo pacman -S --needed base-devel autoconf automake bash binutils bison \
bzip2 fakeroot file findutils flex gawk gcc gettext git grep groff \
gzip libelf libtool libxslt m4 make ncurses openssl patch pkgconf \
python rsync sed texinfo time unzip util-linux wget which zlib
 
# Optional prerequisites, depend on the package selection
sudo pacman -S --needed asciidoc help2man intltool perl-extutils-makemaker swig
cd openwrt
#./scripts/feeds clean
./scripts/feeds update -a
./scripts/feeds install -a
#armlinux下无法编译golang，所以对此有依赖的程序必须删除
#make menuconfig
cp ~/sh/opkg/rpi3b+.config .config
#cp ~/sh/opkg/322-mt7621-fix-cpu-clk-add-clkdev.patch target/linux/ramips/patches-5.10/
#make -j$(nproc) download V=s
#make -j$(nproc) V=s
#the first 
#make -j1 V=s
