sudo apt install sshpass -y
mkdir ~/.ssh
cat ~/id_rsa >> ~/.ssh/id_rsa
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa

sudo service sshd restart
