local assets = import 'assets.libsonnet';
local k8s = import 'k8s.libsonnet';
local master = import 'master.libsonnet';
local metacontroller = import 'metacontroller.libsonnet';
local rbac = import 'rbac.libsonnet';
local subdomain = import 'subdomain.libsonnet';
local utils = import 'utils.libsonnet';
local workers = import 'workers.libsonnet';

function(request) {
  // Wrap the raw request object to add functions.
  local observed = metacontroller.observed(request),
  local spec = observed.parent.spec,

  local rbacComps = rbac.components(observed, spec),
  local subdomainComps = subdomain.components(observed, spec),
  local assetsComps = assets.components(observed, spec),
  local masterComps = master.components(observed, spec),
  local workersComps = workers.components(observed, spec),

  children:
    rbacComps.desired
    + assetsComps.desired
    + subdomainComps.desired
    + workersComps.desired
    + masterComps.desired,

  // status of master Job
  status: utils.getKeyOrElse(
    utils.getHead(masterComps.observed),
    'status',
    {}
  ),
}
