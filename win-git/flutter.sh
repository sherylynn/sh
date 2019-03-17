#!/bin/bash
INSTALL_PATH=$HOME/tools
SOFT_HOME=$INSTALL_PATH/flutter
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=flutterrc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=win
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=mac
fi
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PATH="$SOFT_HOME/bin:$PATH"
echo "export PUB_HOSTED_URL=https://pub.flutter-io.cn" > $TOOLSRC
echo "export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn" >> $TOOLSRC
echo "export PATH=$SOFT_HOME/bin:"'$PATH' >> $TOOLSRC
cd $INSTALL_PATH
git clone -b dev https://github.com/flutter/flutter.git $SOFT_HOME
cd $SOFT_HOME
git pull
if [[ $PLATFORM =~ (win) ]]; then
  flutter.bat doctor
else
  flutter doctor
fi
