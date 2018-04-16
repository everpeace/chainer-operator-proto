local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local chj = import "chainerjob.libsonnet";
local volumes = import "volumes.libsonnet";

{
  local volumes = self,

  all(observed, spec)::
    volumes.hostfileDir(observed, spec)
    + volumes.kubectlDir(observed, spec)
    + volumes.assets(observed, spec),

  allMounts(observed, spec, basePath)::
    volumes.hostfileDirMount(observed, spec, basePath+'/generated')
    + volumes.kubectlDirMount(observed, spec, basePath+'/kubectl_dir')
    + volumes.assetsMount(observed, spec, basePath+'/assets'),

  hostfileDir(observed, spec) :: [
    {
      name: 'chainerjob-hostfile-dir',
      emptyDir: {}
    }
  ],
  hostfileDirMount(observed, spec, mountPath) :: [
    {
      name: 'chainerjob-hostfile-dir',
      mountPath: mountPath
    }
  ],

  kubectlDir(observed, spec) :: [
    {
      name: 'chainerjob-kubectl-dir',
      emptyDir: {}
    }
  ],
  kubectlDirMount(observed, spec, mountPath) :: [
    {
      name: 'chainerjob-kubectl-dir',
      mountPath: mountPath
    }
  ],

  assets(observed, spec) :: [
    {
      name: 'chainerjob-assets',
      configMap: {
        name: chj.assetsName(observed, spec),
        items: [
          {
            key: 'gen_hostfile.sh',
            path: 'gen_hostfile.sh',
            mode: 365
          },
          {
            key: 'kube-plm-rsh-agent',
            path: 'kube-plm-rsh-agent',
            mode: 365
          }
        ]
      }
    }
  ],
  assetsMount(observed, spec, mountPath):: [
    {
      name: 'chainerjob-assets',
      mountPath: mountPath
    }
  ]
}
