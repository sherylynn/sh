mkdir -p ~/lib
cp /usr/lib/aarch64-linux-gnu/libxcb.so.1 ~/lib
sed -i 's/BIG-REQUESTS/_IG-REQUESTS/' ~/lib/libxcb.so.1