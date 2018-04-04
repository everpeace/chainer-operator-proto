{
  local chj = self,

  // defaults
  defaults : {
    podManagementPolicy    : 'Parallel',
  },

  // namespace to deploy
  namespace(observed, spec)     :: observed.parent.metadata.namespace,

  // names, keys/values
  jobName(observed, spec)       :: observed.parent.metadata.name,
  assetsName(observed, spec)    :: chj.jobName(observed, spec) + '-assets',
  subdomainName(observed, spec) :: chj.jobName(observed, spec) + '-subdomain',
  masterName(observed, spec)    :: chj.jobName(observed, spec) + '-master',
  workersName(observed, spec)   :: chj.jobName(observed, spec) + '-worker',
  labelKeyPrefix(observed, spec):: 'chainerjobs.k8s.chainer.org',
  jobLabelKey(observed, spec)   :: chj.labelKeyPrefix(observed, spec) + '/name',
  roleLabelKey(observed, spec)  :: chj.labelKeyPrefix(observed, spec) + '/role',
  masterLabelValue               : 'master',
  workerLabelValue               : 'worker',

  // labels to be injected
  labels(observed, spec)        :: {
    [chj.jobLabelKey(observed, spec)]: chj.jobName(observed, spec)
  },
  masterLabels(observed, spec)  :: chj.labels(observed, spec) {
    [chj.roleLabelKey(observed, spec)]: chj.masterLabelValue
  },
  workerLabels(observed, spec)    :: chj.labels(observed, spec) {
    [chj.roleLabelKey(observed, spec)]: chj.workerLabelValue
  },

  // spec extractors
  spec(observed, spec)          :: observed.parent.spec,
  masterSpec(observed, spec)    :: chj.spec(observed, spec).master,
  workersSpec(observed, spec)   :: chj.spec(observed, spec).workers,

}
