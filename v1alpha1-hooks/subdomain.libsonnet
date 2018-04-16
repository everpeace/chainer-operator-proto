local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local chj = import "chainerjob.libsonnet";

{
  local subdomain = self,

  components(observed, specs) :: metacontroller.collection(observed, specs, "v1", "Service", subdomain.service),

  service(observed, spec)  :: {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      name: chj.subdomainName(observed, spec),
      namespace: chj.namespace(observed, spec),
      labels: chj.labels(observed, spec),
    },
    spec: {
      selector: chj.labels(observed, spec),
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
