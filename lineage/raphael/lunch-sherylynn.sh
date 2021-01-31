#!/bin/zsh
#set ccache
. $(dirname "$0")/../../win-git/toolsinit.sh

export USE_CCACHE=1
PLATFORM=$(platform)
if [[ "$PLATFORM" == "macos" ]]; then
  export CCACHE_EXEC=/usr/local/bin/ccache
  ccache -M 50G
else
  export CCACHE_EXEC=/usr/bin/ccache
  ccache -M 100G
fi
cd ~/android/lineage
source build/envsetup.sh
#按照官方教程，会莫名其妙报错
#C_VERSION TARGET_PLATFORM_VERSION TARGET_PRODUCT print report_config : invalid parameter name
# 需要去掉本地语义化设置
if [ $1 ]; then
  export export JAVACMD_OPTIONS="-Djava.io.tmpdir=$1"
fi
croot
setopt shwordsplit
export LC_ALL=C
#export LD_BIND_NOW=1
#export ALLOW_MISSING_DEPENDENCIES=true
export TEMPORARY_DISABLE_PATH_RESTRICTIONS=true
export LLVM_ENABLE_THREADS=1
#export unset NDK_ROOT

breakfast lineage_raphael-userdebug
brunch lineage_raphael-userdebug
