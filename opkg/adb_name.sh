#!/bin/sh
ANDROID_NAME=$(adb shell getprop ro.product.name)

if [ $ANDROID_NAME = 'gauguinpro' ]; then
  echo 'adb device is gauguinpro'
fi
