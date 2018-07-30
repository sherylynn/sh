if [ ! -d "$HOME/.jupyter" ]; then
  mkdir $HOME/.jupyter
fi
docker run --name jupyter \
  -p 10000:8888 \
  -itd --restart=always \
  -v $HOME:/home/jovyan \
  jupyter/tensorflow-notebook
