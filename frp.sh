#!/bin/bash
sudo apt install axel wget aria2 -y
#!/bin/bash
FRP_VERSION=0.14.1
FRP_ARCH=amd64
#FRP_ARCH=arm
while getopts 'v:a:' OPT; do
  case $OPT in
    v)
      FRP_VERSION="$OPTARG";;
    a)
      FRP_ARCH="$OPTARG";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

aria2c https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
#axel -n 10 https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
    tar -xzf frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
sudo mv frp_${FRP_VERSION}_linux_${FRP_ARCH} ~/frp && \
    rm frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz