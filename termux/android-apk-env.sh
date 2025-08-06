#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

# Android APK 编译环境一键安装脚本
# 基于 sdk.sh, ndk.sh, llama.cpp.sh 整合

echo "开始安装 Android APK 编译环境..."

# 配置变量
AUTHOR=lzhiyong
NDK_VERSION=android-ndk-r27b
SDK_VERSION=android-sdk
TOOLSRC_NAME=android-apk-env
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

# 检测架构
case $(arch) in
  amd64) SOFT_ARCH=x86_64 ;;
  386) SOFT_ARCH=386 ;;
  armhf) SOFT_ARCH=armhf ;;
  aarch64) SOFT_ARCH=aarch64 ;;
esac

PLATFORM=$(platform)
INSTALL_PATH=$(install_path)

echo "检测到平台: $PLATFORM"
echo "检测到架构: $SOFT_ARCH"

# 只在 Linux 环境下安装
if [[ $(platform) == *linux* ]]; then

  echo "正在安装 Android SDK..."

  # SDK 安装
  SDK_HOME=${INSTALL_PATH}/${SDK_VERSION}
  SDK_FILE_PACK=${SDK_VERSION}-aarch64.zip
  SDK_URL=https://github.com/${AUTHOR}/termux-ndk/releases/download/${SDK_VERSION}/${SDK_FILE_PACK}

  $(cache_downloader $SDK_FILE_PACK $SDK_URL)
  $(cache_unpacker $SDK_FILE_PACK $SDK_VERSION)

  rm -rf ${SDK_HOME} &&
    mv $(cache_folder)/${SDK_VERSION} ${SDK_HOME}

  echo "正在安装 Android NDK..."

  # NDK 安装
  NDK_HOME=${INSTALL_PATH}/android-ndk
  NDK_FILE_PACK=${NDK_VERSION}-aarch64.zip
  NDK_URL=https://github.com/${AUTHOR}/termux-ndk/releases/download/android-ndk/${NDK_FILE_PACK}

  $(cache_downloader $NDK_FILE_PACK $NDK_URL)
  $(cache_unpacker $NDK_FILE_PACK android-ndk)

  rm -rf ${NDK_HOME} &&
    mv $(cache_folder)/android-ndk ${NDK_HOME}

  # 创建 NDK 软链接到 SDK
  ln -sf ${NDK_HOME}/${NDK_VERSION} ${SDK_HOME}/${SDK_VERSION}/ndk

  echo "正在配置环境变量..."

  # 配置环境变量
  cat >${TOOLSRC} <<EOF
export ANDROID_HOME=${SDK_HOME}/${SDK_VERSION}
export ANDROID_SDK_ROOT=${SDK_HOME}/${SDK_VERSION}
export ANDROID_NDK_HOME=${NDK_HOME}/${NDK_VERSION}
export PATH=${SDK_HOME}/${SDK_VERSION}/cmdline-tools/latest/bin:${SDK_HOME}/${SDK_VERSION}/platform-tools:${NDK_HOME}/${NDK_VERSION}:\$PATH
EOF

  echo "正在安装必要的依赖包..."

  # 安装必要的包
  pkg update -y
  pkg install git cmake ccache openjdk-17 wget unzip -y
  pkg install gradle -y

  echo "正在创建示例项目结构..."

  # 创建示例项目目录
  mkdir -p ~/android-project/app/src/main/java/com/example/myapp
  mkdir -p ~/android-project/app/src/main/res

  # 创建基本的 build.gradle 文件
  cat >~/android-project/build.gradle <<'EOF'
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.1.0'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
EOF

  # 创建应用级 build.gradle
  cat >~/android-project/app/build.gradle <<'EOF'
plugins {
    id 'com.android.application'
}

android {
    namespace 'com.example.myapp'
    compileSdk 34

    defaultConfig {
        applicationId "com.example.myapp"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
EOF

  # 创建 AndroidManifest.xml
  cat >~/android-project/app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/Theme.MyApp">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
EOF

  # 创建 MainActivity
  cat >~/android-project/app/src/main/java/com/example/myapp/MainActivity.java <<'EOF'
package com.example.myapp;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        TextView tv = new TextView(this);
        tv.setText("Hello, Android!");
        setContentView(tv);
    }
}
EOF

  # 创建 strings.xml
  cat >~/android-project/app/src/main/res/values/strings.xml <<'EOF'
<resources>
    <string name="app_name">My App</string>
</resources>
EOF

  # 创建 gradle.properties
  cat >~/android-project/gradle.properties <<'EOF'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.enableJetifier=true
EOF

  # 创建 settings.gradle
  cat >~/android-project/settings.gradle <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "My Application"
include ':app'
EOF

  # 创建 Gradle Wrapper
  echo "正在创建 Gradle Wrapper..."

  # 创建 gradle/wrapper 目录
  mkdir -p ~/android-project/gradle/wrapper

  # 创建 gradle-wrapper.properties
  cat >~/android-project/gradle/wrapper/gradle-wrapper.properties <<'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.0-bin.zip
networkTimeout=10000
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

  # 创建 gradlew 脚本
  cat >~/android-project/gradlew <<'EOF'
#!/bin/sh

#
# Copyright © 2015-2021 the original authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

##############################################################################
#
#   Gradle start up script for POSIX generated by Gradle.
#
#   Important for running:
#
#   (1) You need a POSIX-compliant shell to run this script. If your /bin/sh is
#       noncompliant, but you have some other compliant shell such as ksh or
#       bash, then to run this script, type that shell name before the whole
#       command line, like:
#
#           ksh Gradle
#
#       Busybox and similar reduced shells will NOT work, because this script
#       requires all of these POSIX shell features:
#         * functions;
#         * expansions «$var», «${var}», «${var:-default}», «${var+SET}»,
#           «${var#prefix}», «${var%suffix}», and «$( cmd )»;
#         * compound commands having a testable exit status, especially «case»;
#         * various built-in commands including «command», «set», and «ulimit».
#
#   Important for patching:
#
#   (2) This script targets any POSIX shell, so it avoids extensions provided
#       by Bash, Ksh, etc; in particular arrays are avoided.
#
#       The "traditional" practice of packing multiple parameters into a
#       space-separated string is a well documented source of bugs and security
#       problems, so this is (mostly) avoided, by progressively accumulating
#       options in "$@", and eventually passing that to Java.
#
#       Where the inherited environment variables (DEFAULT_JVM_OPTS, JAVA_OPTS,
#       and GRADLE_OPTS) rely on word-splitting, this is performed explicitly;
#       see the in-line comments for details.
#
#       There are tweaks for specific operating systems such as AIX, CygWin,
#       Darwin, MinGW, and NonStop.
#
#   (3) This script is generated from the Groovy template
#       https://github.com/gradle/gradle/blob/master/subprojects/plugins/src/main/resources/org/gradle/api/internal/plugins/unixStartScript.txt
#       within the Gradle project.
#
#       You can find Gradle at https://github.com/gradle/gradle/.
#
##############################################################################

# Attempt to set APP_HOME

# Resolve links: $0 may be a link
app_path=$0

# Need this for daisy-chained symlinks.
while
    APP_HOME=${app_path%"${app_path##*/}"}  # leaves a trailing /; empty if no leading path
    [ -h "$app_path" ]
do
    ls=$( ls -ld "$app_path" )
    link=${ls#*' -> '}
    case $link in             #(
      /*)   app_path=$link ;; #(
      *)    app_path=$APP_HOME$link ;;
    esac
done

APP_HOME=$( cd "${APP_HOME:-./}" && pwd -P ) || exit

APP_NAME="Gradle"
APP_BASE_NAME=${0##*/}

# Add default JVM options here. You can also use JAVA_OPTS and GRADLE_OPTS to pass JVM options to this script.
DEFAULT_JVM_OPTS='"-Xmx64m" "-Xms64m"'

# Use the maximum available, or set MAX_FD != -1 to use that value.
MAX_FD=maximum

warn () {
    echo "$*"
} >&2

die () {
    echo
    echo "$*"
    echo
    exit 1
} >&2

# OS specific support (must be 'true' or 'false').
cygwin=false
msys=false
darwin=false
nonstop=false
case "$( uname )" in                #(
  CYGWIN* )         cygwin=true  ;; #(
  Darwin* )         darwin=true  ;; #(
  MSYS* | MINGW* )  msys=true    ;; #(
  NONSTOP* )        nonstop=true ;;
esac

CLASSPATH=$APP_HOME/gradle/wrapper/gradle-wrapper.jar


# Determine the Java command to use to start the JVM.
if [ -n "$JAVA_HOME" ] ; then
    if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
        # IBM's JDK on AIX uses strange locations for the executables
        JAVACMD=$JAVA_HOME/jre/sh/java
    else
        JAVACMD=$JAVA_HOME/bin/java
    fi
    if [ ! -x "$JAVACMD" ] ; then
        die "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
    fi
else
    JAVACMD=java
    which java >/dev/null 2>&1 || die "ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
fi

# Increase the maximum file descriptors if we can.
if ! "$cygwin" && ! "$darwin" && ! "$nonstop" ; then
    case $MAX_FD in #(
      max*)
        MAX_FD=$( ulimit -H -n ) ||
            warn "Could not query maximum file descriptor limit"
    esac
    case $MAX_FD in  #(
      '' | soft) :;; #(
      *)
        ulimit -n "$MAX_FD" ||
            warn "Could not set maximum file descriptor limit to $MAX_FD"
    esac
fi

# Collect all arguments for the java command, stacking in reverse order:
#   * args from the command line
#   * the main class name
#   * -classpath
#   * -D...appname settings
#   * --module-path (only if needed)
#   * DEFAULT_JVM_OPTS, JAVA_OPTS, and GRADLE_OPTS environment variables.

# For Cygwin or MSYS, switch paths to Windows format before running java
if "$cygwin" || "$msys" ; then
    APP_HOME=$( cygpath --path --mixed "$APP_HOME" )
    CLASSPATH=$( cygpath --path --mixed "$CLASSPATH" )

    JAVACMD=$( cygpath --unix "$JAVACMD" )

    # Now convert the arguments - kludge to limit ourselves to /bin/sh
    for arg do
        if
            case $arg in                                #(
              -*)   false ;;                            # don't mess with options #(
              /?*)  t=${arg#/} t=/${t%%/*}              # looks like a POSIX filepath
                    [ -e "$t" ] ;;                      #(
              *)    false ;;
            esac
        then
            arg=$( cygpath --path --ignore --mixed "$arg" )
        fi
        # Roll the args list around exactly as many times as the number of
        # args, so each arg winds up back in the position where it started, but
        # possibly modified.
        #
        # NB: a `for` loop captures its iteration list before it begins, so
        # changing the positional parameters here affects neither the number of
        # iterations, nor the values presented in `arg`.
        shift                   # remove old arg
        set -- "$@" "$arg"      # push replacement arg
    done
fi

# Collect all arguments for the java command;
#   * $DEFAULT_JVM_OPTS, $JAVA_OPTS, and $GRADLE_OPTS can contain fragments of
#     shell script including quotes and variable substitutions, so put them in
#     double quotes to make sure that they get re-expanded; and
#   * put everything else in single quotes, so that it's not re-expanded.

set -- \
        "-Dorg.gradle.appname=$APP_BASE_NAME" \
        -classpath "$CLASSPATH" \
        org.gradle.wrapper.GradleWrapperMain \
        "$@"

# Stop when "xargs" is not available.
if ! command -v xargs >/dev/null 2>&1
then
    die "xargs is not available"
fi

# Use "xargs" to parse quoted args.
#
# With -n1 it outputs one arg per line, with the quotes and backslashes removed.
#
# In Bash we could simply go:
#
#   readarray ARGS < <( xargs -n1 <<<"$var" ) &&
#   set -- "${ARGS[@]}" "$@"
#
# but POSIX shell has neither arrays nor command substitution, so instead we
# post-process each arg (as a line of input to sed) to backslash-escape any
# character that might be a shell metacharacter, then use eval to reverse
# that process (while maintaining the separation between arguments), and wrap
# the whole thing up as a single "set" statement.
#
# This will of course break if any of these variables contains a newline or
# an unmatched quote.
#

eval "set -- $(
        printf '%s\n' "$DEFAULT_JVM_OPTS $JAVA_OPTS $GRADLE_OPTS" \
        | xargs -n1 \
        | sed ' s~[^-[:alnum:]+,./:=@_]~\\&~g; ' \
        | tr '\n' ' '
    )" '"$@"'

exec "$JAVACMD" "$@"
EOF

  # 创建 gradlew.bat 脚本
  cat >~/android-project/gradlew.bat <<'EOF'
@rem
@rem Copyright 2015 the original author or authors.
@rem
@rem Licensed under the Apache License, Version 2.0 (the "License");
@rem you may not use this file except in compliance with the License.
@rem You may obtain a copy of the License at
@rem
@rem      https://www.apache.org/licenses/LICENSE-2.0
@rem
@rem Unless required by applicable law or agreed to in writing, software
@rem distributed under the License is distributed on an "AS IS" BASIS,
@rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
@rem See the License for the specific language governing permissions and
@rem limitations under the License.
@rem

@if "%DEBUG%"=="" @echo off
@rem ##########################################################################
@rem
@rem  Gradle startup script for Windows
@rem
@rem ##########################################################################

@rem Set local scope for the variables with windows NT shell
if "%OS%"=="Windows_NT" setlocal

set DIRNAME=%~dp0
if "%DIRNAME%"=="" set DIRNAME=.
set APP_BASE_NAME=%~n0
set APP_HOME=%DIRNAME%

@rem Resolve any "." and ".." in APP_HOME to make it shorter.
for %%i in ("%APP_HOME%") do set APP_HOME=%%~fi

@rem Add default JVM options here. You can also use JAVA_OPTS and GRADLE_OPTS to pass JVM options to this script.
set DEFAULT_JVM_OPTS="-Xmx64m" "-Xms64m"

@rem Find java.exe
if defined JAVA_HOME goto findJavaFromJavaHome

set JAVA_EXE=java.exe
%JAVA_EXE% -version >NUL 2>&1
if %ERRORLEVEL% equ 0 goto execute

echo.
echo ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
echo.
echo Please set the JAVA_HOME variable in your environment to match the
echo location of your Java installation.

goto fail

:findJavaFromJavaHome
set JAVA_HOME=%JAVA_HOME:"=%
set JAVA_EXE=%JAVA_HOME%/bin/java.exe

if exist "%JAVA_EXE%" goto execute

echo.
echo ERROR: JAVA_HOME is set to an invalid directory: %JAVA_HOME%
echo.
echo Please set the JAVA_HOME variable in your environment to match the
echo location of your Java installation.

goto fail

:execute
@rem Setup the command line

set CLASSPATH=%APP_HOME%\gradle\wrapper\gradle-wrapper.jar


@rem Execute Gradle
"%JAVA_EXE%" %DEFAULT_JVM_OPTS% %JAVA_OPTS% %GRADLE_OPTS% "-Dorg.gradle.appname=%APP_BASE_NAME%" -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*

:end
@rem End local scope for the variables with windows NT shell
if %ERRORLEVEL% equ 0 goto mainEnd

:fail
rem Set variable GRADLE_EXIT_CONSOLE if you need the _script_ return code instead of
rem the _cmd.exe /c_ return code!
if  not "" == "%GRADLE_EXIT_CONSOLE%" exit 1
exit /b 1

:mainEnd
if "%OS%"=="Windows_NT" endlocal

:omega
EOF

  # 设置 gradlew 执行权限
  chmod +x ~/android-project/gradlew

  # 尝试下载 gradle-wrapper.jar
  echo "正在下载 gradle-wrapper.jar..."
  if command -v wget >/dev/null 2>&1; then
    wget -O ~/android-project/gradle/wrapper/gradle-wrapper.jar https://services.gradle.org/distributions/gradle-wrapper.jar 2>/dev/null ||
      wget -O ~/android-project/gradle/wrapper/gradle-wrapper.jar https://raw.githubusercontent.com/gradle/gradle/v8.0/gradle/wrapper/gradle-wrapper.jar 2>/dev/null ||
      echo "警告: 无法下载 gradle-wrapper.jar"
  fi

  # 如果下载失败，尝试使用 gradle 命令生成 wrapper
  if [ ! -f ~/android-project/gradle/wrapper/gradle-wrapper.jar ] && command -v gradle >/dev/null 2>&1; then
    echo "尝试使用 gradle 命令生成 wrapper..."
    cd ~/android-project && gradle wrapper --gradle-version 8.0
  fi

  # 如果仍然失败，创建空文件作为占位符并提供解决方案
  if [ ! -f ~/android-project/gradle/wrapper/gradle-wrapper.jar ]; then
    touch ~/android-project/gradle/wrapper/gradle-wrapper.jar
    echo "警告: 创建了空的 gradle-wrapper.jar 文件作为占位符"
    echo ""
    echo "解决方案："
    echo "1. 手动下载 gradle-wrapper.jar："
    echo "   wget -O ~/android-project/gradle/wrapper/gradle-wrapper.jar https://services.gradle.org/distributions/gradle-wrapper.jar"
    echo "2. 或者使用 gradle 命令生成："
    echo "   cd ~/android-project && gradle wrapper --gradle-version 8.0"
    echo "3. 或者从现有 Android 项目复制："
    echo "   cp /path/to/other/android/project/gradle/wrapper/gradle-wrapper.jar ~/android-project/gradle/wrapper/"
  fi

  echo "安装完成！"
  echo ""
  echo "环境变量已配置在: ${TOOLSRC}"
  echo "Android SDK 安装在: ${SDK_HOME}"
  echo "Android NDK 安装在: ${NDK_HOME}"
  echo ""
  echo "示例项目已创建在: ~/android-project"
  echo ""
  echo "使用方法:"
  echo "1. 重新加载 shell 配置: source ~/.zshrc 或执行 zr"
  echo "2. 进入示例项目: cd ~/android-project"
  echo "3. 构建项目: ./gradlew assembleDebug"
  echo ""
  echo "常用命令:"
  echo "- sdkmanager: 管理 Android SDK 包"
  echo "- adb: Android 调试桥"
  echo "- ndk-build: NDK 构建工具"

else
  echo "错误: 此脚本仅在 Linux 环境下支持"
  exit 1
fi
