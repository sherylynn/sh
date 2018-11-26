#just for termux ,so it is lack of sudo
echo "add .local/bin to path first"
apt install libcrypt-dev libzmq libzmq-dev
pip3 install --user jupyter numpy 
# env
PIP3_PATH=$(python3 -m site --user-base)"/bin"
export PATH=$PATH:$PIP3_PATH
echo "export PATH=\$PATH:"${PIP3_PATH} >> ~/.bashrc
cd ~
if [ ! -d "$HOME/.jupyter" ]; then
  mkdir $HOME/.jupyter
fi
mkdir -p $(jupyter --data-dir)/nbextensions
cd $(jupyter --data-dir)/nbextensions
git clone https://github.com/lambdalisue/jupyter-vim-binding vim_binding
jupyter nbextension enable vim_binding/vim_binding
jupyter notebook password
