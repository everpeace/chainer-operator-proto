local metacontroller = import "metacontroller.libsonnet";
local common = import "common.libsonnet";
{
  local rb = self,

  components(observed, spec):: metacontroller.collection(observed, [spec], "rbac.authorization.k8s.io/v1", "RoleBinding", rb.rolebinding),

  rolebinding(observed, spec):: {
    local metadata = observed.parent.metadata,

    apiVersion: "rbac.authorization.k8s.io/v1",
    kind: "RoleBinding",

    metadata: {
      name:  common.rolebindingName(observed, spec),
      namespace: common.namespace(observed, spec),
      labels: common.labels(observed, spec),
    },

    roleRef: {
      apiGroup: "rbac.authorization.k8s.io",
      kind: "Role",
      name: common.roleName(observed, spec),
    },

    subjects: [{
      kind: "ServiceAccount",
      name: common.saName(observed, spec),
    }],
  }
}
