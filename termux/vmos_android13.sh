#!/data/data/com.termux/files/usr/bin/bash
#adb connect 127.0.0.1:5555
#adb wait-for-device
#adb devices
#adb shell su for magisk
#pause
#kernelsu for termux


#adb shell "su -c 'settings put global settings_enable_monitor_phantom_proc false'"
#ANDROID_VERSION=$(sudo getprop |grep ro.build.version.release] |awk -F '[][]' '{print $4}')
ANDROID_VERSION=$(sudo getprop ro.build.version.release)
#命令太长需要括号起来
echo $ANDROID_VERSION
if [[ $ANDROID_VERSION == 12 ]]; then
  echo "android12"
  adb shell "su -c '/system/bin/device_config set_sync_disabled_for_tests persistent'"
  adb shell "su -c '/system/bin/device_config put activity_manager max_phantom_processes 2147483647'"
fi
if [[ $ANDROID_VERSION == 13 ]]; then
  sudo settings put global settings_enable_monitor_phantom_proc false
fi
if [[ $ANDROID_VERSION == 14 ]]; then
  sudo setprop persist.sys.fflag.override.settings_enable_monitor_phantom_procs false
fi
