#just for termux ,so it is lack of sudo
apt install libcrypt-dev libzmq libzmq-dev
pip3 install --user jupyter numpy jupyter_contrib_nbextensions
cd ~
if [ ! -d "$HOME/.jupyter" ]; then
  mkdir $HOME/.jupyter
fi
jupyter contrib nbextension install --user
jupyter nbextensions_configurator enable --user
mkdir -p $(jupyter --data-dir)/nbextensions
cd $(jupyter --data-dir)/nbextensions
git clone https://github.com/lambdalisue/jupyter-vim-binding vim_binding
chmod -R go-w vim_binding
jupyter notebook password
