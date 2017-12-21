#!/bin/bash
sudo apt install axel -y
FRP_VERSION=0.14.1
FRP_ARCH=amd64
axel -n 10 https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
    tar -xzf frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
sudo mv node-v${NODE_VERSION}-linux-${NODE_ARCH} ~/frp && \
    rm frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz