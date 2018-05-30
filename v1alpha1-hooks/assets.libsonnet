local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local common = import "common.libsonnet";
{
  local assets = self,

  components(observed, spec):: metacontroller.collection(observed, [spec], "v1", "ConfigMap", assets.configMap),

  configMap(observed, spec):: {
    local spec = common.spec(observed, spec),
    local metadata = observed.parent.metadata,
    local workerSpec = common.workerSpec(observed, spec),

    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name:  common.assetsName(observed, spec),
      namespace: common.namespace(observed, spec),
      labels: common.labels(observed, spec),
    },
    data: {
      'download_kubectl.sh': importstr "assets_download_kubectl.sh",
      local gen_hostfile_sh = importstr "assets_gen_hostfile.sh",
      'gen_hostfile.sh': gen_hostfile_sh % {
        namespace: common.namespace(observed, spec),
        subdomainName: common.subdomainName(observed, spec),
        jobLabelKey: common.jobLabelKey(observed, spec),
        jobName: common.jobName(observed, spec),
        roleLabelKey: common.roleLabelKey(observed, spec),
        workerLabelValue: common.workerLabelValue,
        masterLabelValue: common.masterLabelValue,
        clusterSize: if 'replicas' in workerSpec then workerSpec.replicas else 0,
      },

      'kubexec.sh': importstr "assets_kubexec.sh",
    }
  },
}
