#!/bin/bash

# 检查第一个参数是否为 "true"
if [ "$1" = "true" ]; then
  # 如果是 "true", 则开启合成器
  xfconf-query -c xfwm4 -p /general/use_compositing -s true
  echo "XFCE compositor enabled."
else
  # 否则 (包括没有参数的情况), 关闭合成器
  xfconf-query -c xfwm4 -p /general/use_compositing -s false
  echo "XFCE compositor disabled."
fi
