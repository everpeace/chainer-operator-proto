local metacontroller = import "metacontroller.libsonnet";
local common = import "common.libsonnet";
{
  local sa = self,

  components(observed, spec):: metacontroller.collection(observed, [spec], "v1", "ServiceAccount", sa.serviceAccount),

  serviceAccount(observed, spec):: {
    local metadata = observed.parent.metadata,
    apiVersion: "v1",
    kind: "ServiceAccount",
    metadata: {
      name:  common.saName(observed, spec),
      namespace: common.namespace(observed, spec),
      labels: common.labels(observed, spec),
    },
    automountServiceAccountToken: true,
  },
}
