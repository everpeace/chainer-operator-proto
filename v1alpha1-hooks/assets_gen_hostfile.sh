#! /bin/sh
set -xev

MASTER_POD_NAME=${1}
KUBECTL=${2:-/kubeflow/chainer-operator/kubectl_dir/kubectl}
TARGET=${3}
NUM_GPU=${4:-0}
MAX_TRY=${5:-100}
SLEEP_SECS=${6:-5}

trap "rm -f ${TARGET}_new" EXIT TERM INT KILL

tried=0
until [ "$(wc -l < ${TARGET}_new)" -eq %(clusterSize)d ]; do
  worker_pod_names=$($KUBECTL -n %(namespace)s get pod \
    --selector='%(jobLabelKey)s=%(jobName)s,%(roleLabelKey)s=%(workerLabelValue)s' \
    --field-selector=status.phase=Running \
    -o=jsonpath='{.items[*].metadata.name}')

  rm -f ${TARGET}_new
  if [ ${NUM_GPU} -gt 1 ]; then
    SLOTS="slots:${NUM_GPU}"
  else
    SLOTS="slots:1"
  fi
  echo "${MASTER_POD_NAME} ${SLOTS}" > ${TARGET}_new
  for p in ${worker_pod_names}; do
    echo "${p} ${SLOTS}" >> ${TARGET}_new
  done

  tried=$(expr $tried + 1)
  if [ -n "$MAX_TRY" ] && [ $tried -ge $MAX_TRY ]; then
    break
  fi
  sleep $SLEEP_SECS
done

if [ -e ${TARGET}_new ]; then
  mv ${TARGET}_new ${TARGET}
fi
