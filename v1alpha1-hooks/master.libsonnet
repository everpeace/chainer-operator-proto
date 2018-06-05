local common = import 'common.libsonnet';
local k8s = import 'k8s.libsonnet';
local metacontroller = import 'metacontroller.libsonnet';
local utils = import 'utils.libsonnet';
local volumes = import 'volumes.libsonnet';
{
  local master = self,

  components(observed, spec)::
    metacontroller.collection(observed, [spec], 'batch/v1', 'Job', master.job),

  job(observed, spec):: std.prune({
    local masterSpec = common.masterSpec(observed, spec),
    local podTemplate = masterSpec.template,

    apiVersion: 'batch/v1',
    kind: 'Job',

    local desiredMetadata = utils.getKeyOrElse(podTemplate, 'metadata', {}),
    local desiredLabels = utils.getKeyOrElse(desiredMetadata, 'labels', {}),
    metadata: desiredMetadata {
      name: common.masterName(observed, spec),
      labels: desiredLabels + common.masterLabels(observed, spec),
    },

    spec: {
      activeDeadlineSeconds: if 'activeDeadlineSeconds' in masterSpec then
        masterSpec.activeDeadlineSeconds
      else
        {},
      backoffLimit: if 'backoffLimit' in masterSpec then
        masterSpec.backoffLimit
      else
        {},
      template: {
        spec: podTemplate.spec {
          serviceAccount: common.saName(observed, spec),

          restartPolicy: if 'restartPolicy' in podTemplate.spec then
            podTemplate.spec.restartPolicy
          else
            common.constants.restartPolicy,

          volumes:
            utils.getKeyOrElse(podTemplate.spec, 'volumes', [])
            + volumes.all(observed, spec),

          local workerSpec = common.workerSpec(observed, spec),
          local desiredInitContainers = utils.getKeyOrElse(podTemplate.spec, 'initContainers', []),
          local desiredContainers = utils.getKeyOrElse(podTemplate.spec, 'containers', []),

          initContainers: if workerSpec.replicas > 0 then
            [{
              name: 'chainer-operator-kubectl-downloader',
              image: 'tutum/curl',
              command: ['/kubeflow/chainer-operator/assets/download_kubectl.sh'],
              args: ['/kubeflow/chainer-operator/kubectl_dir'],
              volumeMounts: volumes.allMounts(observed, spec, '/kubeflow/chainer-operator'),
            }, {
              name: 'chainer-operator-hostfile-generator',
              image: 'alpine:latest',
              imagePullPolicy: 'IfNotPresent',
              command: ['/kubeflow/chainer-operator/assets/gen_hostfile.sh'],
              args: [
                '$(POD_NAME)',
                '/kubeflow/chainer-operator/kubectl_dir/kubectl',
                '/kubeflow/chainer-operator/generated/hostfile',
              ],
              env: [{
                name: 'POD_NAME',
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.name',
                  },
                },
              }],
              volumeMounts: volumes.allMounts(observed, spec, '/kubeflow/chainer-operator'),
            }] + desiredInitContainers
          else desiredInitContainers,

          containers: [c {
            env+: [{
              name: 'OMPI_MCA_btl_tcp_if_exclude',
              value: 'lo,docker0',
            }, {
              name: 'OMPI_MCA_plm_rsh_agent',
              value: '/kubeflow/chainer-operator/assets/kubexec.sh',
            }, {
              name: 'OMPI_MCA_orte_keep_fqdn_hostnames',
              value: 't',
            }, {
              name: 'OMPI_MCA_orte_default_hostfile',
              value: '/kubeflow/chainer-operator/generated/hostfile',
            }, {
              name: 'KUBCTL',
              value: '/kubeflow/chainer-operator/kubectl_dir/kubectl',
            }],
            volumeMounts+: volumes.allMounts(observed, spec, '/kubeflow/chainer-operator'),
          } for c in desiredContainers],
        },
      },
    },
  }),

  isCompleted(observedMaster)::
    local completed = k8s.conditionStatus(observedMaster, 'Complete') == 'True';
    local failed = k8s.conditionStatus(observedMaster, 'Failed') == 'True';
    completed || failed,
}
