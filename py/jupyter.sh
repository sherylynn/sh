pip3 install --user jupyter numpy
cd ~
if [ ! -d "$HOME/.jupyter" ]; then
  mkdir $HOME/.jupyter
fi
jupyter notebook password
