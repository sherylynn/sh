apt install libcrypt-dev libzmq libzmq-dev
pip3 install jupyter numpy
cd ~
if [ ! -d "$HOME/.jupyter" ]; then
  mkdir $HOME/.jupyter
fi
jupyter notebook password
