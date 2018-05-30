local k8s = import "k8s.libsonnet";
local metacontroller = import "metacontroller.libsonnet";
local subdomain = import "subdomain.libsonnet";
local assets = import "assets.libsonnet";
local sa = import "serviceaccount.libsonnet";
local role = import "role.libsonnet";
local rb = import "rolebinding.libsonnet";
local master = import "master.libsonnet";
local workers = import "workers.libsonnet";
local utils = import "utils.libsonnet";

function(request) {
  // Wrap the raw request object to add functions.
  local observed = metacontroller.observed(request),
  local spec = observed.parent.spec,
  local saComps = sa.components(observed, spec),
  local roleComps = role.components(observed, spec),
  local rbComps = rb.components(observed, spec),
  local subdomainComps = subdomain.components(observed, spec),
  local assetsComps = assets.components(observed, spec),
  local masterComps = master.components(observed, spec),
  local workersComps = workers.components(observed, spec),
  local masterJobStatus = k8s.getKeyOrElse(
    utils.getHead(masterComps.observed),
    'status',
    {}
  ),

  children:
    saComps.desired
    + roleComps.desired
    + rbComps.desired
    + assetsComps.desired
    + subdomainComps.desired
    + workersComps.desired
    + masterComps.desired,

  status: masterJobStatus,
}
