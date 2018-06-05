local k8s = import 'k8s.libsonnet';
local utils = import 'utils.libsonnet';

{
  local common = self,

  // defaults
  constants: {
    podManagementPolicy: 'Parallel',
    restartPolicy: 'Never',
  },

  // namespace to deploy
  namespace(observed, spec):: observed.parent.metadata.namespace,

  // names, keys/values
  jobName(observed, spec):: observed.parent.metadata.name,
  assetsName(observed, spec):: common.jobName(observed, spec) + '-assets',
  saName(observed, spec):: common.jobName(observed, spec) + '-launcher',
  roleName(observed, spec):: common.saName(observed, spec) + '-role',
  rolebindingName(observed, spec):: common.saName(observed, spec) + '-rolebiding',
  subdomainName(observed, spec):: common.jobName(observed, spec),
  masterName(observed, spec):: common.jobName(observed, spec) + '-master',
  workersName(observed, spec):: common.jobName(observed, spec) + '-worker',
  labelKeyPrefix(observed, spec):: 'chainerjobs.kubeflow.org',
  jobLabelKey(observed, spec):: common.labelKeyPrefix(observed, spec) + '/name',
  roleLabelKey(observed, spec):: common.labelKeyPrefix(observed, spec) + '/role',
  masterLabelValue: 'master',
  workerLabelValue: 'worker',

  // labels to be injected
  labels(observed, spec):: {
    [common.jobLabelKey(observed, spec)]: common.jobName(observed, spec),
  },
  masterLabels(observed, spec):: common.labels(observed, spec) {
    [common.roleLabelKey(observed, spec)]: common.masterLabelValue,
  },
  workerLabels(observed, spec):: common.labels(observed, spec) {
    [common.roleLabelKey(observed, spec)]: common.workerLabelValue,
  },

  // spec extractors
  spec(observed, spec):: observed.parent.spec,
  masterSpec(observed, spec):: utils.getKeyOrElse(common.spec(observed, spec), 'master', {}),
  workerSpec(observed, spec)::
    local s = utils.getKeyOrElse(common.spec(observed, spec), 'worker', {});
    if s == {} then
      { replicas: 0 }
    else s {
      replicas: if 'replicas' in s then s.replicas else 1,
    },
}
