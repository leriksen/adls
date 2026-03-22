locals {
  me = "00e67771-2882-40d1-a0c4-899f624ea97d"

  # Map keyed by storage account name
  storage_map = { for sa in var.storage : sa.name => sa }

  # Per-SA map consumed by the adls_container_and_paths module
  adls_module_map = {
    for sa in var.storage : sa.name => {
      sa_name    = sa.name
      containers = sa.containers
      paths      = sa.paths
    }
  }
}