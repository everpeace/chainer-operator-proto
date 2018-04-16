local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local chj = import "chainerjob.libsonnet";
{
  local assets = self,

  components(observed, specs):: metacontroller.collection(observed, specs, "v1", "ConfigMap", assets.configMap),

  configMap(observed, spec):: {
    local spec = chj.spec(observed, spec),
    local metadata = observed.parent.metadata,

    apiVersion: 'v1',
    kind: 'ConfigMap',

    metadata: {
      name:  chj.assetsName(observed, spec),
      namespace: chj.namespace(observed, spec),
      labels: chj.labels(observed, spec),
    },

    data: {
      'gen_hostfile.sh': |||
        set -xev

        target=$1
        max_try=$2

        trap "rm -f ${target}_new" EXIT TERM INT KILL

        tried=0
        until [ "$(wc -l < ${target}_new)" -eq %(clusterSize)d ]; do
          master_name=$(kubectl -n %(namespace)s get pod \
            --selector='%(jobLabelKey)s=%(jobName)s,%(roleLabelKey)s=%(masterLabelValue)s' \
            -o=jsonpath='{.items[*].metadata.name}' | head -1)

          worker_names=$(kubectl -n %(namespace)s get pod \
            --selector='%(jobLabelKey)s=%(jobName)s,%(roleLabelKey)s=%(workerLabelValue)s' \
            --field-selector=status.phase=Running \
            -o=jsonpath='{.items[*].metadata.name}')

          rm -f ${target}_new
          echo "${master_name}" > ${target}_new
          for p in ${worker_names}; do
            echo "${p}" >> ${target}_new
          done

          tried=$(expr $tried + 1)
          if [ -n "$max_try" ] && [ $max_try -ge $tried ]; then
            break
          fi
        done

        if [ -e ${target}_new ]; then
          mv ${target}_new ${target}
        fi
      ||| % {
        namespace: chj.namespace(observed, spec),
        subdomainName: chj.subdomainName(observed, spec),
        jobLabelKey: chj.jobLabelKey(observed, spec),
        jobName: chj.jobName(observed, spec),
        roleLabelKey: chj.roleLabelKey(observed, spec),
        workerLabelValue: chj.workerLabelValue,
        masterLabelValue: chj.masterLabelValue,
        clusterSize: spec.worker.replicas + 1
      },

      'kube-plm-rsh-agent': |||
        #! /bin/bash
        pod=$1
        shift
        ${CHAINERJOB_KUBCTL_DIR}/kubectl exec -i $pod -c chainer -- $@
      |||
    }
  },

  status(assets):: {
    local metadata = k8s.getKeyOrElse(assets, 'metadata', {}),
    name: if 'name' in metadata then metadata.name else '',
    apiVersion: if 'apiVersion' in assets then assets.apiVersion else '',
    kind: if 'kind' in assets then assets.kind else '',
  }
}
