#!/bin/bash
export PULSE_SERVER=127.0.0.1
export GTK_IM_MODULE="fcitx"
export QT_IM_MODULE="fcitx"
export XMODIFIERS="@im=fcitx"
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export TU_DEBUG=noconform
export VK_ICD_FILENAMES=/root/tools/mesa-for-android-container/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
unset GALLIUM_DRIVER
unset MESA_GL_VERSION_OVERRIDE
glmark2
