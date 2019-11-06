#!/bin/bash
. $(dirname "$0")/toolsinit.sh
SOFT_HOME=$(install_path)/Android/Sdk
LIBS_HOME=$(install_path)/Android/android-studio
TOOLSRC_NAME=androidrc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)
#--------------------------
#URL=
#--------------------------
#------load module---------
. ./winPath.sh
#--------------------------
export ANDROID_STUDIO_HOME=$LIBS_HOME
export ANDROID_ABI=arm64-v8a
export SDK_HOME=$SOFT_HOME
export CLASSPATH=.:$LIBS_HOME/jre/lib/tools.jar:$LIBS_HOME/jre/lib/dt.jar:$LIBS_HOME/jre/jre/lib/rt.jar
export JAVA_HOME=$LIBS_HOME/jre
export GRADLE_HOME=$LIBS_HOME/gradle/gradle-4.10.1

tee $TOOLSRC <<EOF
export ANDROID_STUDIO_HOME=$LIBS_HOME
export SDK_HOME=$SOFT_HOME
export ANDROID_HOME=$SOFT_HOME
export ANDROID_ABI=$ANDROID_ABI
export ANDROID_SDK_ROOT=$SOFT_HOME
export ANDROID_SDK=$SOFT_HOME
export ANDROID_NDK=$SOFT_HOME/ndk-bundle
export CLASSPATH=.:$LIBS_HOME/jre/lib/tools.jar:$LIBS_HOME/jre/lib/dt.jar:$LIBS_HOME/jre/jre/lib/rt.jar
export JAVA_HOME=$LIBS_HOME/jre
export GRADLE_HOME=$LIBS_HOME/gradle/gradle-4.10.1
export PATH=\$PATH:$GRADLE_HOME/bin:$ANDROID_STUDIO_HOME/jre/jre/bin:$ANDROID_STUDIO_HOME/jre/bin:$ANDROID_STUDIO_HOME/bin:$SDK_HOME/emulator:$SDK_HOME/platform-tools
EOF
