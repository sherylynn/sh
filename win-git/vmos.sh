#adb connect 127.0.0.1:5555
#adb wait-for-device
#adb devices
adb shell "device_config put activity_manager max_phantom_processes 2147483647"
#adb shell device_config "set_sync_disabled_for_tests" persistent
adb shell "/system/bin/dumpsys activity settings | grep max_phantom_processes"
#pause
