local common = import 'common.libsonnet';
local metacontroller = import 'metacontroller.libsonnet';
{
  local rbac = self,

  components(observed, spec)::
    local sas = metacontroller.collection(observed,
                                          [spec],
                                          'v1',
                                          'ServiceAccount',
                                          rbac.serviceAccount);
    local roles = metacontroller.collection(observed,
                                            [spec],
                                            'rbac.authorization.k8s.io/v1',
                                            'Role',
                                            rbac.role);
    local bndgs = metacontroller.collection(observed,
                                            [spec],
                                            'rbac.authorization.k8s.io/v1',
                                            'RoleBinding',
                                            rbac.rolebinding);

    {
      observed: sas.observed + roles.observed + bndgs.observed,
      desired: sas.desired + roles.desired + bndgs.desired,
    },

  serviceAccount(observed, spec):: {
    local metadata = observed.parent.metadata,
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      name: common.saName(observed, spec),
      namespace: common.namespace(observed, spec),
      labels: common.labels(observed, spec),
    },
    automountServiceAccountToken: true,
  },

  role(observed, spec):: {
    local metadata = observed.parent.metadata,
    local workerSpec = common.workerSpec(observed, spec),

    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'Role',
    metadata: {
      name: common.roleName(observed, spec),
      namespace: common.namespace(observed, spec),
      labels: common.labels(observed, spec),
    },
    rules: [{
      apiGroups: [''],
      resources: ['pods'],
      verbs: ['get', 'list'],
    }, {
      apiGroups: [''],
      resources: ['pods/exec'],
      resourceNames:
        [
          common.workersName(observed, spec) + '-' + n
          for n in std.range(0, workerSpec.replicas - 1)
        ],
      verbs: ['create'],
    }],
  },

  rolebinding(observed, spec):: {
    local metadata = observed.parent.metadata,

    apiVersion: 'rbac.authorization.k8s.io/v1',
    kind: 'RoleBinding',

    metadata: {
      name: common.rolebindingName(observed, spec),
      namespace: common.namespace(observed, spec),
      labels: common.labels(observed, spec),
    },

    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: common.roleName(observed, spec),
    },

    subjects: [{
      kind: 'ServiceAccount',
      name: common.saName(observed, spec),
    }],
  },
}
