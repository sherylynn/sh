pre_breakfast.sh
debian.sh
breakfast.sh
~/android/maruos/out/target/product/oneplus3/
#查了官方，maru0.7就是没写desktop这个setting
#https://github.com/maruos/android_platform_packages_apps_Settings/tree/maru-0.7/src/com/android/settings
下无desktop文件夹
#官方的maru0.7的manifest不保证是能用的

https://github.com/pintaf/manifest/tree/maru-0.7-pintaf
0.7
#解读一下，里面的 app setting就是 setting的界面


repo init -u git://github.com/deepak-divakar/manifest.git -b maru-lineage-17.1 --no-clone-bundle --depth=1
0.8

# 不管是自己迁移的17.1 的aosip 还是17.1 raphael-devs的 都有一个error叫 系统内部自带error
# 并且 会crash desktop option in setting

# tingyichen 的17.1 直接不能build 有error
