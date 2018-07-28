sudo pip3 install jupyter
cd ~
if [ ! -d "$HOME/.jupyter" ]; then
  mkdir $HOME/.jupyter
fi
jupyter notebook password
