#anaconda
conda create -n tensorflow pip python=3.5
source activate tensorflow  #source deactivate
#cpu-only
pip install --ignore-installed --upgrade \
  https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-1.5.0-cp35-cp35m-linux_x86_64.whl
#docker
docker run -it gcr.io/tensorflow/tensorflow bash
#docker with Jupyter notebook
docker run -it -p 8888:8888 gcr.io/tensorflow/tensorflow
#gpu support
nvidia-docker run -it gcr.io/tensorflow/tensorflow:latest-gpu bash
#gpu support with Jupyter notebook
nvidia-docker run -it -p 8888:8888 gcr.io/tensorflow/tensorflow:latest-gpu


#validate
import tensorflow as tf
hello=tf.constant('hi')
sess=tf.Session()
print(sess.run(hello))