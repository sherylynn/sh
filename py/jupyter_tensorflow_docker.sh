docker run --name jupyter_tensorflow \
  -p 10000:8888 \
  -itd --restart=always \
  -v $HOME:/home/jovyan/work \
  jupyter/tensorflow-notebook
