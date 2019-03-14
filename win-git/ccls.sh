INSTALL_PATH=$HOME/tools
SOFT_HOME=$INSTALL_PATH/ccls
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=cclsrc
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
export PATH="$SOFT_HOME/Release:$PATH"
echo "export PATH=$SOFT_HOME/Release:"'$PATH' >> $TOOLSRC
sudo apt install clang-7 libclang-7-dev cmake
cd $INSTALL_PATH
git clone --depth=1 --recursive https://github.com/MaskRay/ccls
cd $SOFT_HOME
git pull
cmake -H. -BRelease -DCMAKE_PREFIX_PATH=/usr/lib/llvm-7
cmake --build Release
#cmake --build Release --target install
