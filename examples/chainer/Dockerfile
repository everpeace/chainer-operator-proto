ARG BASE_CHAINER_IMAGE_TAG="v4.0.0b4-python3"
FROM chainer/chainer:$BASE_CHAINER_IMAGE_TAG

RUN apt-get update && apt-get install -y wget && \
  wget https://raw.githubusercontent.com/chainer/chainer/v4.0.0b4/examples/mnist/train_mnist.py \
  -O /train_mnist.py
