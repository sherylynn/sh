volumes_name=macSSD
patch_kext=$(ls |grep kext)
cp kernel /Volumes/${volumes_name}/System/Library/Kernels
cp prelinkedkernel /Volumes/${volumes_name}/System/Library/PrelinkedKernels/prelinkedkernel.test
cp -R $patch_kext /Volumes/${volumes_name}/System/Library/Extensions
cd /Volumes/${volumes_name}/System/Library/Extensions/
chmod -R 755 $patch_kext
chown -R root:wheel $patch_kext
rm -Rf /Volumes/${volumes_name}/System/Library/PrelinkedKernels/prelinkedkernel
kextcache -u /Volumes/${volumes_name}/
