#!/bin/bash
SOFT_VERSION=5.3.5
SOFT_NAME=lua-${SOFT_VERSION}
SOFT_PACK=${SOFT_NAME}.tar.gz
cd ~
curl -o ${SOFT_PACK} -L http://www.lua.org/ftp/${SOFT_PACK}
mkdir -p ${SOFT_NAME}
tar -xzf ${SOFT_PACK} -C ${SOFT_NAME}
cd ${SOFT_NAME}/${SOFT_NAME}
make mingw
cp -R src ~/tools/lua
