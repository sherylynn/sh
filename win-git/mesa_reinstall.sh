#filelist1=$(tar tf ~/tools/cache/vulkan-freedreno-1-26.1.0-1-aarch64.pkg.tar.xz|grep -v '/$' |tr '\n' ' ' ; echo)
filelist1=$(
  tar tf ~/tools/cache/mesa-for-android-container_26.0.0-devel-20260116_debian_trixie_arm64.tar.gz | grep -v '/$' | tr '\n' ' '
  echo
)
echo $filelist1
filelist2=$(
  tar tf ~/tools/cache/turnip_26.0.0-devel-20260116_debian_trixie_arm64.tar.gz | grep -v '/$' | tr '\n' ' '
  echo
)
cd /
rm -rf $filelist1 $filelist2
sudo apt install --reinstall libegl-mesa0 libgbm1 libgl1-mesa-dri libglx-mesa0 mesa-libgallium mesa-vulkan-drivers -y
