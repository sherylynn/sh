#!/bin/bash
INSTALL_PATH=$HOME/tools
SOFT_HOME=$INSTALL_PATH/Android/Sdk
LIBS_HOME=$INSTALL_PATH/Android/android-studio
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=androidrc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
if [[ "$(uname)" =~ (MINGW)|(MSYS) ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=win
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=Linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=MacOS
fi

#--------------------------
#URL=
#--------------------------
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
echo "export ANDROID_HOME=$LIBS_HOME" > $TOOLSRC
echo "export SDK_HOME=$SOFT_HOME" >> $TOOLSRC
echo 'export CLASSPATH=.:$ANDROID_HOME/jre/lib/tools.jar:$ANDROID_HOME/jre/lib/dt.jar:$ANDROID_HOME/jre/jre/lib/rt.jar' >> $TOOLSRC
echo 'export JAVA_HOME=$ANDROID_HOME/jre' >> $TOOLSRC
echo 'export GRADLE_HOME=$ANDROID_HOME/gradle/gradle-4.10.1' >> $TOOLSRC
echo 'export PATH=$PATH:$GRADLE_HOME/bin:$ANDROID_HOME/bin:$SDK_HOME/emulator:$SDK_HOME/platform-tools' >> $TOOLSRC
