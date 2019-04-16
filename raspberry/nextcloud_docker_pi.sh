#!/bin/bash
#注意hgfs挂载时候的权限问题
COMMAND="n"
#先在getopts里设好要用的参数
while getopts 'rs' OPT; do
  case $OPT in
    r)
      COMMAND="y";;
    s)
      COMMAND="n";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))


if [ ${COMMAND} = "y" ]; then
docker-compose -f nextcloud_pi.yml up -d
fi
if [ ${COMMAND} = "n" ]; then
#docker-compose -f /home/pi/sh/raspberry/nextcloud_pi.yml stop
docker-compose -f nextcloud_pi.yml stop
fi
