cd ~
git clone -b 22.03 --single-branch https://github.com/Lienol/openwrt.git
sudo apt-get -y install build-essential asciidoc binutils bzip2 curl gawk gettext git libncurses5-dev libz-dev patch python3.5 python2.7 unzip zlib1g-dev lib32gcc1 libc6-dev-i386 subversion flex uglifyjs git-core gcc-multilib p7zip p7zip-full msmtp libssl-dev texinfo libglib2.0-dev xmlto qemu-utils upx libelf-dev autoconf automake libtool autopoint device-tree-compiler g++-multilib antlr3 gperf
cd openwrt
#./scripts/feeds clean
./scripts/feeds update -a
./scripts/feeds install -a
#make menuconfig
cp ~/sh/opkg/ea8100v2.config .config
cp ~/sh/opkg/322-mt7621-fix-cpu-clk-add-clkdev.patch target/linux/ramips/patches-5.10/
make -j$(nproc) download V=s
#make -j$(nproc) V=s
#the first 
make -j1 V=s
