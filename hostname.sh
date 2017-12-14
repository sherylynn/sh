hostname -I
sysctl kernel.hostname
sudo sysctl kernel.hostname=ubt
echo 127.0.0.1 localhost ubt |sudo tee -a /etc/hosts