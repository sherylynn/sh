if [ ! -d "$HOME/.local" ]; then
  mkdir $HOME/.local
fi
if [ ! -d "$HOME/.jupyter" ]; then
  mkdir $HOME/.jupyter
fi
#因为权限原因，需要把挂载的文件权限改为uid为1000，在docker中可以更改保存
#没直接挂载$HOME目录，是因为主机是root用户，没法挂载
#如果主机用户非root，可以直接挂载
#主机用户为root时候，ubuntu下直接安装jupyter都有问题，干
chown -R 1000 $HOME/.jupyter $HOME/.local $HOME/toys
docker run --name jupyter \
  --privileged=true \
  -p 10000:8888 \
  -itd --restart=always \
  -v $HOME/toys:/home/jovyan/toys \
  jupyter/tensorflow-notebook
