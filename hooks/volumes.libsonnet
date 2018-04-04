local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local chj = import "chainerjob.libsonnet";
local volumes = import "volumes.libsonnet";

{
  local volumes = self,

  all(observed, spec)::
    volumes.hostfileDir(observed, spec)
    + volumes.assets(observed, spec)
    + volumes.sshKey(observed, spec),

  allMounts(observed, spec, basePath)::
    volumes.hostfileDirMount(observed, spec, basePath+'/generated')
    + volumes.assetsMount(observed, spec, basePath+'/assets')
    + volumes.sshKeyMount(observed, spec, basePath+'/sshKey'),

  hostfileDir(observed, spec) :: [
    {
      name: 'chainerjob-hostfile-dir',
      emptyDir: {}
    }
  ],
  hostDirMount(observed, spec, mountPath) :: [
    {
      name: 'chainerjob-hostfile-dir',
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
            key: 'init.sh',
            path: 'init.sh',
            mode: 365
          },
          {
            key: 'start_sshd.sh',
            path: 'start_sshd.sh',
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
  ],

  sshKey(observed, spec) :: [
    {
      name: 'chainerjob-sshkey',
      secret: {
        secretName: chj.spec(observed, spec).sshKey,
        defaultMode: 256,
      }
    }
  ],
  sshKeyMount(observed, spec, mountPath) :: [
    {
      name: 'chainerjob-sshkey',
      mountPath: mountPath
    }
  ]
}
