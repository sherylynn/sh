#!/bin/bash
#cd ~/android/maruos/vender/maruos/blueprints
#./build.sh -b debian -n deb -- -r buster -a arm64 --minimal
if [ ! -f ~/blueprints/out/maru-* ]; then
  ../../maruos/build_deb_arm64.sh
fi
cp ~/blueprints/out/maru-* ~/android/maruos/prebuilts/desktop-rootfs.tar.gz
