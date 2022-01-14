mkdir ~/.ssh
cat ~/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

echo PasswordAuthentication no|sudo tee -a /etc/ssh/sshd_config
sudo tee -a /etc/ssh/sshd_config <<-'EOF'
AuthorizedKeysFile .ssh/authorized_keys
PubkeyAuthentication yes
EOF

#sudo service sshd restart
sudo systemctl restart ssh
