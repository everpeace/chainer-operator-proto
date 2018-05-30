local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local common = import "common.libsonnet";

{
  local subdomain = self,

  components(observed, spec) ::
    metacontroller.collection(
      observed, [spec], "v1", "Service", subdomain.service
    ),

  service(observed, spec)  :: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: common.subdomainName(observed, spec),
      namespace: common.namespace(observed, spec),
      labels: common.labels(observed, spec),
    },
    spec: {
      selector: common.labels(observed, spec),
      clusterIP: 'None',
      ports: [
        {
          name: 'dummy',
          port: 1234,
          targetPort: 1234,
        }
      ]
    },
  }
}
