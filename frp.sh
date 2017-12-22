#!/bin/bash
sudo apt install axel wget -y
FRP_VERSION=0.14.1
FRP_ARCH=amd64
wget https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
#axel -n 10 https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
    tar -xzf frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
sudo mv frp_${FRP_VERSION}_linux_${FRP_ARCH} ~/frp && \
    rm frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz