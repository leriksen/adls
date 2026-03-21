locals {
  me = "00e67771-2882-40d1-a0c4-899f624ea97d"

  # Map keyed by storage account name
  storage_map = { for sa in var.storage : sa.name => sa }

  # Flatten containers: key = "sa_name:container_name"
  containers_flat = {
    for pair in flatten([
      for sa in var.storage : [
        for c in sa.containers : {
          key       = "${sa.name}:${c.name}"
          sa_name   = sa.name
          container = c
        }
      ]
    ]) : pair.key => pair
  }

  # Flatten paths: key = "sa_name:container_name:path"
  paths_flat = {
    for pair in flatten([
      for sa in var.storage : [
        for c in sa.containers : [
          for p in c.paths : {
            key            = "${sa.name}:${c.name}:${p}"
            sa_name        = sa.name
            container_name = c.name
            path           = p
          }
        ]
      ]
    ]) : pair.key => pair
  }
}
