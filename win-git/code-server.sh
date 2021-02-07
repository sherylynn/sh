curl -fsSL https://code-server.dev/install.sh |sh
#systemd autostart
#sudo systemctl enable code-server@$USER
#sudo systemctl start code-server@$USER

#configure
#~/.config/code-server/config.yaml

#reuse extension
rm -rf ~/.local/share/code-server
ln -s ~/.vscode ~/.local/share/code-server
