Volumes_name=macSSD
patch_kext=$(ls *.kext)
cp kernel /Volumes/${volumes_name}/System/Library/Kernels
cp -R $patch_kext /Volumes/${volumes_name}/System/Library/Extensions
cd /Volumes/${volumes_name}/System/Library/Extensions/
chmod -R 755 $patch_kext
chown -R root:wheel $patch_kext
rm -Rf /Volumes/${volumes_name}/System/Library/PrelinkedKernels/prelinkedkernel
kextcache -u /Volumes/${volumes_name}/
