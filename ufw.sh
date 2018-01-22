sudo apt install ufw
ufw allow ssh
ufw enable
ufw default deny
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 28000
ufw allow 29000