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
#export JAVA_HOME=$LIBS_HOME/jre
export JAVA_HOME=$LIBS_HOME/jbr
export GRADLE_HOME=$LIBS_HOME/gradle/gradle-4.10.1

# Set Java 17 path for macOS with homebrew
if [[ $(platform) == *macos* ]]; then
    BREW_JAVA17_HOME="/opt/homebrew/opt/openjdk@17"
    if [[ -d "$BREW_JAVA17_HOME" ]]; then
        export JAVA_HOME=$BREW_JAVA17_HOME
    fi
fi

# --- SDK Installation (from termux/sdk.sh) ---
SDK_VERSION=android-sdk
SOFT_FILE_PACK_SDK=${SDK_VERSION}-aarch64.zip
SOFT_URL_SDK=https://github.com/lzhiyong/termux-ndk/releases/download/${SDK_VERSION}/${SOFT_FILE_PACK_SDK}

if [[ $(platform) == *linux* ]] && [[ $(arch) == aarch64 ]]; then
  echo "Downloading and installing Android SDK..."
  $(cache_downloader $SOFT_FILE_PACK_SDK $SOFT_URL_SDK)
  $(cache_unpacker $SOFT_FILE_PACK_SDK $SDK_VERSION)

  mkdir -p ${SDK_HOME} &&
    rm -rf ${SDK_HOME} &&
    mv $(cache_folder)/${SDK_VERSION} ${SDK_HOME}
fi

# --- NDK Installation (from termux/ndk.sh) ---
NDK_VERSION_NAME=android-ndk
NDK_VERSION_FULL=android-ndk-r27b
SOFT_FILE_PACK_NDK=${NDK_VERSION_FULL}-aarch64.zip
SOFT_URL_NDK=https://github.com/lzhiyong/termux-ndk/releases/download/${NDK_VERSION_NAME}/${SOFT_FILE_PACK_NDK}

if [[ $(platform) == *linux* ]] && [[ $(arch) == aarch64 ]]; then
  echo "Downloading and installing Android NDK..."
  $(cache_downloader $SOFT_FILE_PACK_NDK $SOFT_URL_NDK)
  $(cache_unpacker $SOFT_FILE_PACK_NDK ${NDK_VERSION_FULL})

  mkdir -p ${SDK_HOME}/ndk &&
    rm -rf ${SDK_HOME}/ndk &&
    mv $(cache_folder)/${NDK_VERSION_FULL} ${SDK_HOME}/ndk
fi

if [[ $(platform) == *macos* ]]; then
  tee $TOOLSRC <<EOF
export JAVA_HOME=$JAVA_HOME
EOF
else
  tee $TOOLSRC <<EOF
export ANDROID_STUDIO_HOME=$LIBS_HOME
export SDK_HOME=$SOFT_HOME
export ANDROID_HOME=$SOFT_HOME
export ANDROID_ABI=$ANDROID_ABI
export ANDROID_SDK_ROOT=$SOFT_HOME
export ANDROID_SDK=$SOFT_HOME
export ANDROID_NDK=$SDK_HOME/ndk
export CLASSPATH=.:$LIBS_HOME/jre/lib/tools.jar:$LIBS_HOME/jre/lib/dt.jar:$LIBS_HOME/jre/jre/lib/rt.jar
#export JAVA_HOME=$LIBS_HOME/jre
export JAVA_HOME=$LIBS_HOME/jbr
export GRADLE_HOME=$LIBS_HOME/gradle/gradle-4.10.1
export PATH=\$PATH:$GRADLE_HOME/bin:$ANDROID_STUDIO_HOME/jre/jre/bin:$ANDROID_STUDIO_HOME/jre/bin:$ANDROID_STUDIO_HOME/bin:$SDK_HOME/emulator:$SDK_HOME/platform-tools:$ANDROID_STUDIO_HOME/jbr/bin:$SDK_HOME/cmdline-tools/latest/bin:$SDK_HOME/ndk
EOF
fi
sudo apt-get install qemu-kvm libvirt-clients libvirt-daemon-system virtinst bridge-utils -y
