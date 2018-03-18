LEANOTE_VERSION=2.6.1
LEANOTE_ARCH=amd64
wget https://sourceforge.net/projects/leanote-bin/files/${LEANOTE_VERSION}/leanote-linux-${LEANOTE_ARCH}v${LEANOTE_VERSION}.bin.tar.gz/download
cd ~
#tar -xzvf leanote-linux-${LEANOTE_ARCH}v${LEANOTE_VERSION}
tar -xzvf download
mongorestore -h localhost -d leanote --dir ~/leanote/mongodb_backup/leanote_install_data/
mongod --dbpath  ~/mongo_data/ --auth
cd ~/leanote/bin
bash run.sh
