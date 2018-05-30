local metacontroller = import "metacontroller.libsonnet";
local common = import "common.libsonnet";
{
  local r = self,

  components(observed, spec):: metacontroller.collection(observed, [spec], "rbac.authorization.k8s.io/v1", "Role", r.role),

  role(observed, spec):: {
    local workerSpec = common.workerSpec(observed, spec),
    local replicas = if 'replicas' in workerSpec then replicas else 0,
    local workersName = common.workersName(observed, spec),
    local masterName = common.masterName(observed, spec),
    local metadata = observed.parent.metadata,

    apiVersion: "rbac.authorization.k8s.io/v1",
    kind: "Role",
    metadata : {
      name:  common.roleName(observed, spec),
      namespace: common.namespace(observed, spec),
      labels: common.labels(observed, spec),
    },
    rules: [{
      apiGroups: [""],
      resources: ["pods"],
      verbs: ["get", "list"],
    }, {
      apiGroups: [""],
      resources: ["pods/exec"],
      resourceNames:
        [ workersName + "-" + n
          for n in std.range(0, replicas - 1) ],
      verbs: ["create"],
    }],
  },
}
