#adb connect 127.0.0.1:5555
#adb wait-for-device
#adb devices
#adb shell su for magisk
adb shell "su -c 'settings put global settings_enable_monitor_phantom_proc false'"
#pause
#kernelsu for termux
sudo settings put global settings_enable_monitor_phantom_proc false
