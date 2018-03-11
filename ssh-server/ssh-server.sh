#/bin/bash
docker run -itd --name ssh-server --restart=always -p 22001:22 \
  -v ~/storage:/root/storage \
  ssh-server
