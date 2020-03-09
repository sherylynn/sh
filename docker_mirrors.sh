sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"]
}
EOF
#"registry-mirrors": ["https://8znzd6qv.mirror.aliyuncs.com"]
sudo systemctl daemon-reload
sudo systemctl restart docker
#https://hlef81mt.mirror.aliyuncs.com
