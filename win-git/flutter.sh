#!/bin/bash
INSTALL_PATH=$HOME/tools
SOFTHOME=$INSTALL_PATH/flutter
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=flutterrc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
fi
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PATH="$SOFTHOME/bin:$PATH"
echo "export PUB_HOSTED_URL=https://pub.flutter-io.cn" > $TOOLSRC
echo "export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn" >> $TOOLSRC
echo "export PATH=$SOFTHOME/bin:"'$PATH' >> $TOOLSRC
cd $INSTALL_PATH
git clone -b dev https://github.com/flutter/flutter.git $SOFTHOME
cd $SOFTHOME
git pull
flutter doctor
