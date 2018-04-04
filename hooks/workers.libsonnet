local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local chj = import "chainerjob.libsonnet";
local volumes = import "volumes.libsonnet";
local master = import "master.libsonnet";
local utils = import "utils.libsonnet";

{
  local workers = self,

  components(observed, specs)::
    metacontroller.collection(observed, specs, "apps/v1", "StatefulSet", workers.statefulset),

  statefulset(observed, spec):: {
    local podTemplate        = spec.worker.template,
    local desiredMetadata    = k8s.getKeyOrElse(podTemplate, 'metadata', {}),
    local desiredLabels      = k8s.getKeyOrElse(desiredMetadata, 'labels', {}),
    local observedMaster     = utils.getHead(
      master.components(observed, [ observed.parent.spec ]).observed
    ),

    apiVersion: 'apps/v1',
    kind: 'StatefulSet',

    metadata: desiredMetadata {
      name:  chj.workersName(observed, spec),
      namespace: chj.namespace(observed, spec),
      labels: desiredLabels + chj.workerLabels(observed, spec),
    },

    spec: {
      selector: {
        matchLabels: desiredLabels + chj.workerLabels(observed, spec)
      },

      podManagementPolicy: chj.defaults.podManagementPolicy,
      serviceName: chj.subdomainName(observed, spec),
      replicas: if master.isCompleted(observedMaster) then
        0
      else
        spec.worker.replicas,

      template: podTemplate {
        metadata: desiredMetadata {
          labels: desiredLabels + chj.workerLabels(observed, spec),
        },
        spec: podTemplate.spec {
          local desiredVolumes = k8s.getKeyOrElse(podTemplate.spec, 'volumes', []),
          volumes:
            desiredVolumes
            + volumes.assets(observed, spec)
            + volumes.sshKey(observed, spec),
          local desiredContainers = k8s.getKeyOrElse(podTemplate.spec, 'containers', []),
          containers: [ c {

            local desiredCommand = k8s.getKeyOrElse(c, 'command', []),
            local name = k8s.getKeyOrElse(c, 'name', ''),
            command: if name == 'chainer' then
              [ '$(CHAINERJOB_ASSETS_DIR)/init.sh' ]
            else
              desiredCommand,

            local desiredPorts = k8s.getKeyOrElse(c, 'ports', []),
            ports: if name == 'chainer' then
              desiredPorts + [{
                containerPort: 20022
              }]
            else
              desiredPorts,

            env +: [
              { name: 'CHAINERJOB_ASSETS_DIR', value: '/chainerjob/assets'},
              { name: 'CHAINERJOB_SSH_KEY_DIR', value: '/chainerjob/sshKey'},
              { name: 'CHAINERJOB_ROLE', value: 'worker'},
              { name: 'OMPI_MCA_btl', value: 'tcp,self' },
              { name: 'OMPI_MCA_btl_tcp_if_include', value:'eth0' },
              { name: 'OMPI_MCA_plm_rsh_no_tree_spawn', value: '1' },
              { name: 'OMPI_MCA_orte_keep_fqdn_hostnames', value: 't'},
            ],

            volumeMounts +: [
              volumes.assetsMount(observed, spec, '/chainerjob/assets')[0],
              volumes.sshKeyMount(observed, spec, '/chainerjob/sshKey')[0]
            ]
          } for c in desiredContainers ]
        }
      }
    }
  }
}
