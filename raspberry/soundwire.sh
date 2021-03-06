cd $HOME
if [ ! -d "$HOME/tools" ]; then
  mkdir $HOME/tools
fi
sudo apt install wget -y
wget http://georgielabs.altervista.org/SoundWire_Server_RPi.tar.gz
tar -C $HOME/tools  -xvf SoundWire_Server_RPi.tar.gz
rm SoundWire_Server_RPi.tar.gz
sudo apt install -y pulseaudio:armhf pavucontrol:armhf libportaudio2:armhf
echo 'export PATH=$PATH:$HOME/tools/dist'>>~/.bashrc
