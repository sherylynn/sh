#!/bin/bash
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=easy_commandrc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)

#---------------------------------------------
mumu(){
  adb connect 127.0.0.1:7555
}
cat <<EOF > $TOOLSRC
mumu(){
  adb connect 127.0.0.1:7555
}
EOF
#---------------------------------------------
:<<comment
#大段内容注释
:是空命令
上面的cat实现其实也可以用tee tee可以结合sudo cat不能
comment
