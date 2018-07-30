if [ ! -d "$HOME/jupyterhub" ]; then
  mkdir $HOME/jupyterhub
fi
docker run -p 10000:8000 -d -v $HOME/jupyterhub:/jupyterhub --name jupyterhub jupyterhub/jupyterhub jupyterhub
#就算是0.8.1 login完后还是有一个错误说can't start server
