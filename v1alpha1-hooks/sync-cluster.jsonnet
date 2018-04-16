local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local subdomain = import "subdomain.libsonnet";
local assets = import "assets.libsonnet";
local master = import "master.libsonnet";
local workers = import "workers.libsonnet";
local utils = import "utils.libsonnet";
function(request) {
  // Wrap the raw request object to add functions.
  local observed = metacontroller.observed(request),

  local subdomainComps = subdomain.components(observed, [ observed.parent.spec ]),
  local assetsComps = assets.components(observed, [ observed.parent.spec ]),
  local masterComps = master.components(observed, [ observed.parent.spec ]),
  local workersComps = workers.components(observed, [ observed.parent.spec ]),

  status: {
    local observedSubdomain = utils.getHead(subdomainComps.observed),
    subdomain: k8s.info(observedSubdomain),

    local observedAssets = utils.getHead(assetsComps.observed),
    assets: k8s.info(observedAssets),

    local observedMaster = utils.getHead(masterComps.observed),
    local observedMasterReadyStatus = k8s.conditionStatus(observedMaster, "Ready"),
    local observedMasterReadyReason = k8s.conditionReason(observedMaster, "Ready"),
    master: k8s.info(observedMaster) + {
      conditions: [
        k8s.condition("Ready", observedMasterReadyStatus) + {
          reason: observedMasterReadyReason
        }
      ]
    },

    local observedWorker = utils.getHead(workersComps.observed),
    local observedWorkerStatus = if 'status' in observedWorker then
      { status: observedWorker.status }
    else
      {},
    worker:
      k8s.info(observedWorker) + observedWorkerStatus,

    conditions: [
      k8s.condition(
        "Ready",
        observedMasterReadyStatus == "True"
        && 'status' in observedWorker
        && (observedWorker.status.replicas == if 'readyReplicas' in observedWorker.status then observedWorker.status.readyReplicas else null)
        && (observedWorker.status.replicas == if 'currentReplicas' in observedWorker.status then observedWorker.status.currentReplicas else null)
      ),

      local workerScaledDown = 'status' in observedWorker
        && observedWorker.status.replicas == 0;
      k8s.condition(
        "Completed",
        observedMasterReadyStatus == "False"
        && observedMasterReadyReason == "PodCompleted"
        && workerScaledDown
      ) + {
        reason: {
          master: observedMasterReadyReason,
          worker: if workerScaledDown then "ScaledDown" else "NotScaledDown"
        }
      }
    ]
  },
  children:
    subdomainComps.desired
    + assetsComps.desired
    + workersComps.desired
    + masterComps.desired
}
