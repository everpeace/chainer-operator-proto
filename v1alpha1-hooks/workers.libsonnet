local common = import 'common.libsonnet';
local k8s = import 'k8s.libsonnet';
local master = import 'master.libsonnet';
local metacontroller = import 'metacontroller.libsonnet';
local utils = import 'utils.libsonnet';
local volumes = import 'volumes.libsonnet';

{
  local workers = self,

  components(observed, spec)::
    metacontroller.collection(observed,
                              if common.workerSpec(observed, spec).replicas <= 0 then
                                []
                              else
                                [spec],
                              'apps/v1',
                              'StatefulSet',
                              workers.statefulset),

  statefulset(observed, spec):: std.prune({
    local workerSpec = common.workerSpec(observed, spec),
    local podTemplate = workerSpec.template,
    local desiredMetadata = utils.getKeyOrElse(podTemplate, 'metadata', {}),
    local desiredLabels = utils.getKeyOrElse(desiredMetadata, 'labels', {}),
    local observedMaster = utils.getHead(
      master.components(observed, observed.parent.spec).observed
    ),

    apiVersion: 'apps/v1',
    kind: 'StatefulSet',

    metadata: desiredMetadata {
      name: common.workersName(observed, spec),
      namespace: common.namespace(observed, spec),
      labels: desiredLabels + common.workerLabels(observed, spec),
    },

    spec: {
      selector: {
        matchLabels: desiredLabels + common.workerLabels(observed, spec),
      },

      podManagementPolicy: common.constants.podManagementPolicy,
      serviceName: common.subdomainName(observed, spec),
      replicas: if master.isCompleted(observedMaster) then 0 else workerSpec.replicas,

      template: podTemplate {
        metadata: desiredMetadata {
          labels: desiredLabels + common.workerLabels(observed, spec),
        },

        spec: podTemplate.spec {

          serviceAccount: common.saName(observed, spec),

          local desiredVolumes = utils.getKeyOrElse(podTemplate.spec, 'volumes', []),
          volumes: desiredVolumes + volumes.all(observed, spec),


          local desiredInitContainers = utils.getKeyOrElse(podTemplate.spec, 'initContainers', []),
          initContainers: [{
            name: 'chainer-operator-kubectl-downloader',
            image: 'tutum/curl',
            command: ['/kubeflow/chainer-operator/assets/download_kubectl.sh'],
            args: ['/kubeflow/chainer-operator/kubectl_dir'],
            volumeMounts:
              volumes.allMounts(observed, spec, '/kubeflow/chainer-operator'),
          }] + [c {
            volumeMounts+: volumes.allMounts(observed, spec, '/kubeflow/chainer-operator'),
          } for c in desiredInitContainers],


          local desiredContainers = utils.getKeyOrElse(podTemplate.spec, 'containers', []),
          containers: [c {
            env+: [
              {
                name: 'OMPI_MCA_btl_tcp_if_exclude',
                value: 'lo,docker0',
              },
              {
                name: 'OMPI_MCA_plm_rsh_agent',
                value: '/kubeflow/chainer-operator/assets/kubexec.sh',
              },
              {
                name: 'OMPI_MCA_orte_keep_fqdn_hostnames',
                value: 't',
              },
              {
                name: 'KUBCTL',
                value: '/kubeflow/chainer-operator/kubectl_dir/kubectl',
              },
            ],
            volumeMounts+: volumes.allMounts(observed, spec, '/kubeflow/chainer-operator'),
          } for c in desiredContainers],
        },
      },
    },
  }),
}
