sudo apt install curl gnupg -y
curl -fsSL https://ftp-master.debian.org/keys/archive-key-9.asc | sudo apt-key add -
#sudo cp ~/sh/raspberry/sources.list /etc/apt/
sudo tee /etc/apt/sources.list.d/debian.list <<-'EOF'
deb http://mirrors.163.com/debian/ stretch main non-free contrib
EOF
sudo apt update
