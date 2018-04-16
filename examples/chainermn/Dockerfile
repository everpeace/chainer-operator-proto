ARG BASE_CHAINER_IMAGE_TAG="v4.0.0b4-python3"
FROM chainer/chainer:$BASE_CHAINER_IMAGE_TAG

ARG OPENMPI_MAIN_VERSION="2.1"
ARG OPENMPI_PATCH_VERSION="2"
ARG OPENMPI_VERSION="${OPENMPI_MAIN_VERSION}.${OPENMPI_PATCH_VERSION}"
ARG NCCL_PACKAGE_VERSION="2.1.4-1+cuda8.0"
ARG CHAINER_MN_VERSION="1.2.0"

ENV BASE_CHAINER_IMAGE_TAG ${BASE_CHAINER_IMAGE_TAG:-v4.0.0b3-python3}
ENV BASE_CHAINER_IMAGE "chainer/chainer:$BASE_CHAINER_IMAGE_TAG"

# install dependencies
RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
      locales wget sudo ca-certificates ssh build-essential && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

# install openmpi
RUN cd /tmp && \
  wget -q https://www.open-mpi.org/software/ompi/v$OPENMPI_MAIN_VERSION/downloads/openmpi-$OPENMPI_VERSION.tar.bz2 && \
  tar -xjf openmpi-$OPENMPI_VERSION.tar.bz2 && \
  cd /tmp/openmpi-$OPENMPI_VERSION && \
  ./configure --prefix=/usr --with-cuda && \
  make -j2 && \
  make install && \
  rm -r /tmp/openmpi-$OPENMPI_VERSION && rm /tmp/openmpi-$OPENMPI_VERSION.tar.bz2

# check openmpi was built with cuda support
RUN if ! ompi_info --parsable --all | grep -q "mpi_built_with_cuda_support:value:true" ; then \
    exit 1; \
  fi;

# nccl2
RUN apt-get update && apt-get install -yq --no-install-recommends apt-transport-https && \
    wget http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb && \
    dpkg -i nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb && \
    rm nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb && \
    apt-get update && \
    apt-get install -yq --no-install-recommends \
      libnccl-dev=${NCCL_PACKAGE_VERSION} libnccl2=${NCCL_PACKAGE_VERSION} && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# chainermn
RUN _pip="pip" && \
    echo $BASE_CHAINER_IMAGE_TAG && \
    if echo "$BASE_CHAINER_IMAGE_TAG" | grep python3 2>&1 >/dev/null; then _pip="pip3"; fi && \
    $_pip install chainermn==$CHAINER_MN_VERSION

# chainermn mnist example
RUN wget https://raw.githubusercontent.com/chainer/chainermn/v1.2.0/examples/mnist/train_mnist.py -O /train_mnist.py
