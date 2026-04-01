locals {
  me = "00e67771-2882-40d1-a0c4-899f624ea97d"

  # Map keyed by storage account name
  storage_map = { for sa in var.storage : sa.name => sa }

  # Flat map of every queue across all SAs: "sa_name::queue_name" => { sa_name, queue_name, queue_type }
  queue_map = {
    for pair in flatten([
      for sa in var.storage : [
        for q in sa.queues : {
          sa_name    = sa.name
          queue_name = q.name
          queue_type = q.type
        }
      ]
    ]) : "${pair.sa_name}::${pair.queue_name}" => pair
  }

  # Map of SA name → name of the "queue"-type queue (used by event subscriptions)
  sa_event_queue = {
    for sa in var.storage :
    sa.name => [for q in sa.queues : q.name if q.type == "queue"][0]
  }

  # Per-SA map consumed by the adls_container_and_paths module
  adls_module_map = {
    for sa in var.storage : sa.name => {
      sa_name    = sa.name
      containers = sa.containers
      paths      = sa.paths
    }
  }
}