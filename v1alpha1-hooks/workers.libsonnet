local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local chj = import "chainerjob.libsonnet";
local volumes = import "volumes.libsonnet";
local master = import "master.libsonnet";
local utils = import "utils.libsonnet";

{
  local workers = self,

  components(observed, specs)::
    if chj.workerSpec(observed, specs).replicas == 0 then
      metacontroller.collection(observed, [], "apps/v1", "StatefulSet", workers.statefulset)
    else
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
            + volumes.kubectlDir(observed, spec),

          local desiredInitContainers = k8s.getKeyOrElse(podTemplate.spec, 'initContainers', []),
          initContainers: desiredInitContainers + [
            {
              name: 'kubectl-downloader',
              image: 'tutum/curl',
              command: [
                'sh',
                '-c',
                |||
                  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
                  chmod +x kubectl && \
                  mv kubectl /kubectl-download/kubectl
                |||,
              ],
              volumeMounts: volumes.kubectlDirMount(observed, spec, 'kubectl-download'),
            }
          ],

          local desiredContainers = k8s.getKeyOrElse(podTemplate.spec, 'containers', []),
          containers: [ c {
            env +: [
              { name: 'CHAINERJOB_ASSETS_DIR', value: '/chainerjob/assets'},
              { name: 'CHAINERJOB_KUBCTL_DIR', value: '/chainerjob/kubectl_dir'},
              { name: 'OMPI_MCA_btl', value: 'tcp,self' },
              { name: 'OMPI_MCA_btl_tcp_if_include', value:'eth0' },
              { name: 'OMPI_MCA_plm_rsh_no_tree_spawn', value: '1' },
              { name: 'OMPI_MCA_plm_rsh_agent', value: '/chainerjob/assets/kube-plm-rsh-agent'},
              { name: 'OMPI_MCA_orte_keep_fqdn_hostnames', value: 't'},
            ],

            volumeMounts +: [
              volumes.assetsMount(observed, spec, '/chainerjob/assets')[0],
              volumes.kubectlDirMount(observed, spec, 'chainerjob/kubectl_dir')[0]
            ]
          } for c in desiredContainers ]
        }
      }
    }
  }
}
