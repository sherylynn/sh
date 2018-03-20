if [ ! -d "$HOME/jupyterhub" ]; then
  mkdir $HOME/jupyterhub
fi
docker run -p 10000:8000 -d --name jupyterhub jupyterhub/jupyterhub jupyterhub
