sudo dnf -y install dnf-plugins-core
sudo dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf config-manager --set-enabled docker-ce-edge
sudo dnf config-manager --set-enabled docker-ce-test
sudo dnf install docker-ce
sudo systemctl start docker
sudo usermod -aG docker $(whoami)
sudo systemctl restart docker
