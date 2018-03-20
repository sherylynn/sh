if [ ! -d "$HOME/jupyterhub" ]; then
  mkdir $HOME/jupyterhub
fi
docker run -p 10000:8000 -d -v $HOME/jupyterhub:/jupyterhub --name jupyterhub jupyterhub/jupyterhub jupyterhub
