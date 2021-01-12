#!/bin/zsh
NAME=repo
TOOLSRC_NAME=${NAME}rc
TOOLSRC="$(toolsRC ${TOOLSRC_NAME})"
SOFT_HOME=$(install_path)/${NAME}
#SOFT_URL=https://storage.googleapis.com/git-repo-downloads/${NAME}
SOFT_URL=https://mirrors.tuna.tsinghua.edu.cn/git/git-${NAME}
$(cache_downloader $NAME $SOFT_URL)
mkdir -p $SOFT_HOME
cp $(cache_folder)/$NAME $SOFT_HOME/
chmod 777 $SOFT_HOME/$NAME
echo 'export PATH=$PATH:'${SOFT_HOME} > ${TOOLSRC}
echo "export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'" >> ${TOOLSRC}
