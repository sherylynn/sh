cp kernel /Volumes/macSSD/System/Library/Kernels
cp -R IONetworkingFamily.kext /Volumes/macSSD/System/Library/Extensions
chmod -R 755 /Volumes/macSSD/System/Library/Extensions/IONetworkingFamily.kext
chown -R root:wheel /Volumes/macSSD/System/Library/Extensions/IONetworkingFamily.kext
rm -Rf /Volumes/macSSD/System/Library/PrelinkedKernels/prelinkedkernel
kextcache -u /Volumes/macSSD/
