sudo apt install android-tools-adb -y
adb connect 127.0.0.1

adb shell pm list packages |grep camera
adb shell am start -n com.android.camera/com.android.camera.Camera

adb shell "am start -a android.media.action.IMAGE_CAPTURE"

#打开前置拍照摄像头
adb shell am start -a android.media.action.IMAGE_CAPTURE --ei android.intent.extras.CAMERA_FACING 1
#拍摄像
adb shell "input keyevent KEYCODE_CAMERA"
#似乎360手机不响应先后摄像头不同的设置 并且拍照在普通模式下也没

#打开后置摄像录影
adb shell am start -a android.media.action.VIDEO_CAPTURE --ei android.intent.extras.CAMERA_FACING 1
#拍摄像
adb shell "input keyevent KEYCODE_CAMERA"
#保存拍摄
adb shell "input keyevent KEYCODE_CAMERA"
#需要再重新打开录影才能下一段拍摄