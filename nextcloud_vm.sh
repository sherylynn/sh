#!/bin/bash
#注意hgfs挂载时候的权限问题
COMMAND="n"
while getopts 'v:a:sc' OPT; do
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
docker-compose -f ./sh/nextcloud_vm.yml up -d
fi
if [ ${COMMAND} = "n" ]; then
docker-compose -f ./sh/nextcloud_vm.yml stop
fi