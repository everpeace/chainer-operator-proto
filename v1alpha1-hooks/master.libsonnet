local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local chj = import "chainerjob.libsonnet";
local volumes = import "volumes.libsonnet";
{
  local master = self,

  components(observed, specs)::
    metacontroller.collection(observed, specs, "v1", "Pod", master.pod),

  pod(observed, spec):: {
    local podTemplate = chj.masterSpec(observed, spec).template,
    local desiredMetadata = k8s.getKeyOrElse(podTemplate, 'metadata', {}),
    local desiredLabels   = k8s.getKeyOrElse(desiredMetadata, 'labels', {}),

    apiVersion: 'v1',
    kind: 'Pod',

    metadata: desiredMetadata {
      name: chj.masterName(observed, spec),
      labels: desiredLabels + chj.masterLabels(observed, spec),
    },

    spec: podTemplate.spec {
      restartPolicy: 'OnFailure',
      hostname:chj.masterName(observed, spec),
      subdomain: chj.subdomainName(observed, spec),

      local desiredVolumes = k8s.getKeyOrElse(podTemplate.spec, 'volumes', []),
      volumes: desiredVolumes
        + volumes.kubectlDir(observed, spec)
        + if chj.workerSpec(observed, spec).replicas == 0 then
          []
        else
          volumes.hostfileDir(observed, spec)
          + volumes.assets(observed, spec),

      local desiredInitContainers = k8s.getKeyOrElse(podTemplate.spec, 'initContainers', []),
      local hostfileInitializer = if chj.workerSpec(observed, spec).replicas == 0 then
        []
      else [{
        name: 'hostfile-initializer',
        image: 'everpeace/kubectl:1.9.4',
        imagePullPolicy: 'IfNotPresent',
        command: [
          'sh',
          '-c',
          '$(CHAINERJOB_ASSETS_DIR)/gen_hostfile.sh $(CHAINERJOB_HOSTFILE_DIR)/hostfile'
        ],
        env: [
          { name: 'CHAINERJOB_HOSTFILE_DIR', value: '/chainerjob/generated'},
          { name: 'CHAINERJOB_ASSETS_DIR', value: '/chainerjob/assets'}
        ],
        volumeMounts:
          volumes.hostfileDirMount(observed, spec, '/chainerjob/generated')
          + volumes.assetsMount(observed, spec, '/chainerjob/assets')
      }],

      initContainers: desiredInitContainers + hostfileInitializer + [
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
          { name: 'CHAINERJOB_KUBCTL_DIR', value: '/chainerjob/kubectl_dir'}
        ] + if chj.workerSpec(observed, spec).replicas == 0 then
          []
        else
          [{ name: 'CHAINERJOB_HOSTFILE_DIR', value: '/chainerjob/generated'},
            { name: 'CHAINERJOB_ASSETS_DIR', value: '/chainerjob/assets'},
            { name: 'OMPI_MCA_btl_tcp_if_include', value:'eth0' },
            { name: 'OMPI_MCA_plm_rsh_agent', value: '/chainerjob/assets/kube-plm-rsh-agent'},
            { name: 'OMPI_MCA_orte_keep_fqdn_hostnames', value: 't'},
          ],
        volumeMounts +: volumes.kubectlDirMount(observed, spec, '/chainerjob/kubectl_dir')
          + if chj.workerSpec(observed, spec).replicas == 0 then
            []
          else
            volumes.hostfileDirMount(observed, spec, '/chainerjob/generated')
            + volumes.assetsMount(observed, spec, '/chainerjob/assets'),
      } for c in desiredContainers],
    }
  },

  isCompleted(observedMaster)::
    local conditionStatus = k8s.conditionStatus(observedMaster, "Ready");
    local conditionReason = k8s.conditionReason(observedMaster, "Ready");

    conditionStatus == "False" && conditionReason == "PodCompleted"
}
