local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local common = import "common.libsonnet";
local volumes = import "volumes.libsonnet";
local utils = import "utils.libsonnet";
{
  local master = self,

  components(observed, spec)::
    metacontroller.collection(observed, [spec], "batch/v1", "Job", master.job),

  job(observed, spec):: std.prune({
    local masterSpec = common.masterSpec(observed, spec),
    local podTemplate = masterSpec.template,

    apiVersion: 'batch/v1',
    kind: 'Job',

    local desiredMetadata = k8s.getKeyOrElse(podTemplate, 'metadata', {}),
    local desiredLabels   = k8s.getKeyOrElse(desiredMetadata, 'labels', {}),
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

          local desiredVolumes = k8s.getKeyOrElse(podTemplate.spec, 'volumes', []),
          volumes: desiredVolumes + volumes.all(observed, spec),

          local workerSpec = common.workerSpec(observed, spec),
          local replicas = if 'replicas' in workerSpec then workerSpec.replicas else 0,
          local kubectlDownloader = if replicas == 0 then
            []
          else [{
            name: 'chainer-operator-kubectl-downloader',
            image: 'tutum/curl',
            command: [ '/kubeflow/chainer-operator/assets/download_kubectl.sh' ],
            args: [ '/kubeflow/chainer-operator/kubectl_dir' ],
            volumeMounts: volumes.allMounts(observed, spec, '/kubeflow/chainer-operator'),
          }],
          local hostfileGenerator = if replicas == 0 then
            []
          else [{
            name: 'chainer-operator-hostfile-generator',
            image: 'alpine:latest',
            imagePullPolicy: 'IfNotPresent',
            command: [ '/kubeflow/chainer-operator/assets/gen_hostfile.sh' ],
            args: [
              '$(POD_NAME)',
              '/kubeflow/chainer-operator/kubectl_dir/kubectl',
              '/kubeflow/chainer-operator/generated/hostfile'
            ],
            env: [{
              name: 'POD_NAME',
              valueFrom: {
                fieldRef: {
                  fieldPath: 'metadata.name',
                },
              },
            }],
            volumeMounts: volumes.allMounts(observed, spec, '/kubeflow/chainer-operator')
          }],
          local desiredInitContainers = k8s.getKeyOrElse(podTemplate.spec, 'initContainers', []),

          initContainers: kubectlDownloader + hostfileGenerator + desiredInitContainers,

          local desiredContainers = k8s.getKeyOrElse(podTemplate.spec, 'containers', []),
          containers: [ c {
            env +: [{
              name: 'OMPI_MCA_btl_tcp_if_exclude',
              value: 'lo,docker0',
            }, {
              name: 'OMPI_MCA_plm_rsh_agent',
              value: '/kubeflow/chainer-operator/assets/kubexec.sh',
            }, {
              name: 'OMPI_MCA_orte_keep_fqdn_hostnames',
              value: 't'
            }, {
              name: 'OMPI_MCA_orte_default_hostfile',
              value: '/kubeflow/chainer-operator/generated/hostfile',
            },{
              name: 'KUBCTL',
              value: '/kubeflow/chainer-operator/kubectl_dir/kubectl',
            }],
            volumeMounts +: volumes.allMounts(observed, spec, '/kubeflow/chainer-operator'),
          } for c in desiredContainers],
        },
      },
    },
  }),

  isCompleted(observedMaster)::
    local completed = k8s.conditionStatus(observedMaster, "Complete") == "True";
    local failed = k8s.conditionStatus(observedMaster, "Failed") == "True";
    completed || failed,
}
