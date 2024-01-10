#adb connect 127.0.0.1:5555
#adb wait-for-device
#adb devices
#adb shell su for magisk
#pause
#kernelsu for termux


#adb shell "su -c 'settings put global settings_enable_monitor_phantom_proc false'"
ANDROID_VERSION=sudo getprop |grep ro.build.version.release |awk -F '[][]' '{print $4}'
if [[ ANDROID_VERSION == 12 ]]; then
  sudo device_config put activity_manager max_phantom_processes 2147483647
fi
if [[ ANDROID_VERSION == 13 ]]; then
  sudo settings put global settings_enable_monitor_phantom_proc false
fi
if [[ ANDROID_VERSION == 14 ]]; then
  sudo settings put global settings_enable_monitor_phantom_proc false
  sudo setprop persist.sys.fflag.override.settings_enable_monitor_phantom_procs false
fi
