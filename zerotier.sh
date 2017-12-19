只用在moon主机上执行所有命令
zerotier-idtool initmoon /var/lib/zerotier-one/identity.public >> moon.json
zerotier-idtool genmoon moon.json
sudo mkdir /var/lib/zerotier-one/moons.d
cp
zerotier-cli listpeers
zerotier-cli orbit e64d65a908 111.231.90.43
sudo zerotier-cli join 12ac4a1e71394190
sudo zerotier-cli set 12ac4a1e71394190 allowGlobal=1

用moon直连的速度貌似只有moon的上限