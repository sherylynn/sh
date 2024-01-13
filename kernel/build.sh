#!/bin/bash
args="-j $(nproc --all) O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi- LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf OBJSIZE=llvm-size STRIP=llvm-strip LDGOLD=aarch64-linux-gnu-ld.gold LLVM_AR=llvm-ar LLVM_DIS=llvm-dis"
#cd ~/neko_kernel_xiaomi_gauguin/arch/arm64/configs/vendor
cd ~/neko_kernel_xiaomi_gauguin
#make ${args} menuconfig
make ${args} gauguin_user_defconfig
make ${args}
