local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local common = import "common.libsonnet";

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
      name: 'chainer-operator-hostfile-dir',
      emptyDir: {}
    }
  ],
  hostfileDirMount(observed, spec, mountPath) :: [
    {
      name: 'chainer-operator-hostfile-dir',
      mountPath: mountPath,
    }
  ],

  kubectlDir(observed, spec) :: [
    {
      name: 'chainer-operator-kubectl-dir',
      emptyDir: {}
    }
  ],
  kubectlDirMount(observed, spec, mountPath) :: [
    {
      name: 'chainer-operator-kubectl-dir',
      mountPath: mountPath
    }
  ],

  assets(observed, spec) :: [
    {
      name: 'chainer-operator-assets',
      configMap: {
        name: common.assetsName(observed, spec),
        items: [
          {
            key: 'download_kubectl.sh',
            path: 'download_kubectl.sh',
            mode: 365,
          },
          {
            key: 'gen_hostfile.sh',
            path: 'gen_hostfile.sh',
            mode: 365,
          },
          {
            key: 'kubexec.sh',
            path: 'kubexec.sh',
            mode: 365,
          }
        ]
      }
    }
  ],
  assetsMount(observed, spec, mountPath):: [
    {
      name: 'chainer-operator-assets',
      mountPath: mountPath
    }
  ]
}
