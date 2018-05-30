#! /bin/sh
set -ex

TARGET=${1:-/kubeflow/chainer-operator/kubectl_dir}
MAX_TRY=${2:-10}
SLEEP_SECS=${3:-5}
TRIED=0
COMMAND_STATUS=1

until [ $COMMAND_STATUS -eq 0 ] || [ $TRIED -eq $MAX_TRY ]; do
  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && mv kubectl $TARGET/kubectl
  COMMAND_STATUS=$?
  sleep $SLEEP_SECS
  TRIED=$(expr $TRIED + 1)
done
