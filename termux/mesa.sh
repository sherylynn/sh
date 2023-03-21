apt install virglrenderer-android
MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.0 GALLIUM_DRIVER=zink /data/data/com.termux/files/usr/bin/virgl_test_server_android  --use-egl-surfaceless
