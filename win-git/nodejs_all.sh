#!/bin/bash
# source
. "$(dirname "$0")/toolsinit.sh"
TOOLSRC_NAME=noderc
TOOLSRC=$(toolsRC "${TOOLSRC_NAME}")
SOFT_HOME=$(install_path)/node
NODE_GLOBAL=$(install_path)/node-global
NODE_CACHE=$(install_path)/node-cache
SOFT_VERSION=22.23.4
cd ~ || exit 1

PLATFORM=$(platform)
if [[ "$PLATFORM" == "macos" ]]; then
  PLATFORM=darwin
elif [[ "$PLATFORM" == "wslinux" ]]; then
  PLATFORM=linux
fi

case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64) SOFT_ARCH=arm64 ;;
  *)
    echo "错误：不支持的 Node.js 架构：$(arch)" >&2
    exit 1
    ;;
esac

SOFT_FILE_NAME=node-v${SOFT_VERSION}-${PLATFORM}-${SOFT_ARCH}
SOFT_FILE_PACK=$(soft_file_pack "$SOFT_FILE_NAME")
SOFT_URL=https://nodejs.org/dist/v${SOFT_VERSION}/${SOFT_FILE_PACK}
SHASUMS_FILE=SHASUMS256-node-v${SOFT_VERSION}.txt
SHASUMS_URL=https://nodejs.org/dist/v${SOFT_VERSION}/SHASUMS256.txt

verify_node_archive() {
  local archive sums expected actual
  archive="$(cache_folder)/${SOFT_FILE_PACK}"
  sums="$(cache_folder)/${SHASUMS_FILE}"
  expected=$(awk -v file="$SOFT_FILE_PACK" '$2 == file || $2 == "*" file { print $1; exit }' "$sums")
  if [[ -z "$expected" ]]; then
    echo "错误：Node.js 官方 SHASUMS 中找不到 ${SOFT_FILE_PACK}" >&2
    return 1
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$archive" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$archive" | awk '{print $1}')
  elif command -v openssl >/dev/null 2>&1; then
    actual=$(openssl dgst -sha256 "$archive" | awk '{print $NF}')
  else
    echo "错误：缺少 sha256sum/shasum/openssl，无法校验 Node.js 官方包" >&2
    return 1
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "错误：Node.js 安装包 SHA256 校验失败" >&2
    echo "期望：$expected" >&2
    echo "实际：$actual" >&2
    return 1
  fi
}

# 保持原有单版本覆盖安装语义，只升级到当前安全版本。
if [[ "$(node --version 2>/dev/null)" != "v${SOFT_VERSION}" ]]; then
  cache_downloader "$SOFT_FILE_PACK" "$SOFT_URL" || exit 1
  cache_downloader "$SHASUMS_FILE" "$SHASUMS_URL" || exit 1
  verify_node_archive || exit 1
  cache_unpacker "$SOFT_FILE_PACK" "$SOFT_FILE_NAME" || exit 1

  rm -rf "$SOFT_HOME" || exit 1
  mv "$(cache_folder)/${SOFT_FILE_NAME}" "$SOFT_HOME" || exit 1
fi

mkdir -p "$NODE_GLOBAL" "$NODE_CACHE"

# cache_unpacker 会保留归档内的顶层目录，因此沿用原来的 NODE_ROOT 布局。
NODE_ROOT=${SOFT_HOME}/${SOFT_FILE_NAME}
if [[ ${PLATFORM} == win ]]; then
  echo 'export PATH=$PATH:'${NODE_ROOT} >${TOOLSRC}
  echo 'export PATH=$PATH:'${NODE_GLOBAL} >>${TOOLSRC}
  export PATH=$PATH:$NODE_ROOT
  export PATH=$PATH:$NODE_GLOBAL
  export NODE_SKIP_PLATFORM_CHECK=1
else
  echo 'export PATH=$PATH:'${NODE_ROOT}'/bin' >${TOOLSRC}
  echo 'export PATH=$PATH:'${NODE_GLOBAL}'/bin' >>${TOOLSRC}
  export PATH=$PATH:${NODE_ROOT}/bin
  export PATH=$PATH:${NODE_GLOBAL}/bin
fi
echo 'NPM_CONFIG_PREFIX='$NODE_GLOBAL >>${TOOLSRC}
echo 'NPM_CONFIG_CACHE='$NODE_CACHE >>${TOOLSRC}
echo 'YARN_CACHE_FOLDER='$(install_path)'/yarn-cache' >>${TOOLSRC}
echo 'export NODE_SKIP_PLATFORM_CHECK=1' >>${TOOLSRC}

export NPM_CONFIG_PREFIX=$NODE_GLOBAL
export NPM_CONFIG_CACHE=$NODE_CACHE
export YARN_CACHE_FOLDER=$(install_path)/yarn-cache
export ELECTRON_MIRROR=http://npmmirror.com/mirrors/electron/
export SQLITE3_BINARY_SITE=http://npmmirror.com/mirrors/sqlite3
export PHANTOMJS_CDNURL=http://npmmirror.com/mirrors/phantomjs

if [[ "$(node --version 2>/dev/null)" != "v${SOFT_VERSION}" ]]; then
  echo "错误：Node.js 安装失败，当前 $(node --version 2>/dev/null || echo unavailable)，期望 v${SOFT_VERSION}" >&2
  exit 1
fi
#-----------------------------------------------------------
#----------------------------
# Set Global packages path
#----------------------------
npm config set prefix "${NODE_GLOBAL}"
npm config set cache "${NODE_CACHE}"
yarn config set cache-folder "$(install_path)/yarn-cache"
#----------------------------
# Install Basic cli packages
#----------------------------
#npm i -g yrm --registry=https://registry.npmmirror.com
#npm i nrm --registry=https://registry.npmmirror.com --location=global
npm i yrm --registry=https://registry.npmmirror.com --location=global

#npm i cnpm --registry=https://registry.npmmirror.com --location=global
yrm add newtaobao https://registry.npmmirror.com
yrm use newtaobao
echo "con.nvim:registry=https://registry.npmmirror.com" >>~/.npmrc
#nrm use taobao
#npm i -g pouchdb-server webpack yarn http-server j json dva-cli babel-cli code-push express-cli flow-bin  rundev
#x64
#npm i -g react-native-cli rnpm pm2 pouchdb-server npm webpack yrm http-server j json dva-cli babel-cli code-push express-cli flow-bin vue-cli rundev eslint tslint ts-node typescript cordova
#arm
cnpm i yarn webpack http-server babel-cli pm2 typescript ts-node tslint eslint --location=global
# 安装 pnpm
# npm install -g pnpm --registry=https://registry.npmmirror.com
yarn config set cache-folder "$(install_path)/yarn-cache"
#-----------------------
#if [[ $WIN_PATH ]]; then
#  if [[ ${PLATFORM} == win ]]; then
#    setx NPM_CONFIG_PREFIX $(cygpath -w $NPM_CONFIG_PREFIX)
#    setx NPM_CONFIG_CACHE $(cygpath -w $NPM_CONFIG_CACHE)
#    setx YARN_CACHE_FOLDER $(cygpath -w $YARN_CACHE_FOLDER)
#    setx ELECTRON_MIRROR 'http://npmmirror.com/mirrors/electron/'
#    setx SQLITE3_BINARY_SITE 'http://npmmirror.com/mirrors/sqlite3'
#    setx PHANTOMJS_CDNURL 'http://npmmirror.com/mirrors/phantomjs'
#
#    winENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
#    echo $winENV
#    setx Path "$winENV"
#  fi
#fi
