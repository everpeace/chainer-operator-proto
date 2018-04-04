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
      volumes: desiredVolumes + volumes.all(observed, spec),

      local desiredInitContainers = k8s.getKeyOrElse(podTemplate.spec, 'initContainers', []),
      initContainers: desiredInitContainers + [
        {
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
            volumes.hostDirMount(observed, spec, '/chainerjob/generated')
            + volumes.assetsMount(observed, spec, '/chainerjob/assets')
        }
      ],

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
          { name: 'CHAINERJOB_HOSTFILE_DIR', value: '/chainerjob/generated'},
          { name: 'CHAINERJOB_ASSETS_DIR', value: '/chainerjob/assets'},
          { name: 'CHAINERJOB_SSH_KEY_DIR', value: '/chainerjob/sshKey'},
          { name: 'CHAINERJOB_ROLE', value: 'master'},
          { name: 'OMPI_MCA_btl', value: 'tcp,self' },
          { name: 'OMPI_MCA_btl_tcp_if_include', value:'eth0' },
          { name: 'OMPI_MCA_plm_rsh_no_tree_spawn', value: '1' },
          { name: 'OMPI_MCA_orte_keep_fqdn_hostnames', value: 't'},
        ],

        volumeMounts +: [
          volumes.hostDirMount(observed, spec, '/chainerjob/generated')[0],
          volumes.assetsMount(observed, spec, '/chainerjob/assets')[0],
          volumes.sshKeyMount(observed, spec, '/chainerjob/sshKey')[0]
        ]
      } for c in desiredContainers],
    }
  },

  isCompleted(observedMaster)::
    local conditionStatus = k8s.conditionStatus(observedMaster, "Ready");
    local conditionReason = k8s.conditionReason(observedMaster, "Ready");

    conditionStatus == "False" && conditionReason == "PodCompleted"
}
