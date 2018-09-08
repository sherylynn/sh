adb shell settings put global http_proxy 192.168.1.102:10808
#wget https://github.com/shadowsocks/shadowsocks-android/releases/download/v4.6.1/shadowsocks--universal-4.6.1.apk
#adb install shadowsocks--universal-4.6.1.apk
#adb push shadowsocks--universal-4.6.1.apk /sdcard/Download/
adb shell settings delete global global_http_proxy_port
adb shell settings delete global global_http_proxy_host
adb shell settings delete global http_proxy
