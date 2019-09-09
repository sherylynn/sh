#just for termux ,so it is lack of sudo
echo "add .local/bin to path first"
apt install libcrypt-dev libzmq libzmq-dev -y
sudo apt install python3-lxml -y
pip3 install --user jupyter
pip3 install --user jupyter_contrib_nbextensions
# env
#PIP3_PATH=$(python3 -m site --user-base)"/bin"
#export PATH=$PATH:$PIP3_PATH
#echo "export PATH=\$PATH:"${PIP3_PATH} >> ~/.bashrc
cd ~
if [ ! -d "$HOME/.jupyter" ]; then
  mkdir $HOME/.jupyter
fi

# init nbextensions
rm -rf $(jupyter --data-dir)/nbextensions
mkdir -p $(jupyter --data-dir)/nbextensions

#install js css for contrib
jupyter contrib nbextension install --user

# enable extension
jupyter nbextension enable hinterland/hinterland
jupyter nbextension enable code_prettify/autopep8 

# for vim
:<<comment
mkdir -p $(jupyter --data-dir)/nbextensions
cd $(jupyter --data-dir)/nbextensions
git clone https://github.com/lambdalisue/jupyter-vim-binding vim_binding
jupyter nbextension enable vim_binding/vim_binding
comment

jupyter notebook password
