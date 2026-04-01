locals {
  # Object ID of the current user (Leif).
  # Used in RBAC role assignments (me_blob_owner, me_queue_contributor, me_dlq_reader)
  # so that the deploying user has direct data-plane access to all storage accounts.
  me = "00e67771-2882-40d1-a0c4-899f624ea97d"

  # ---------------------------------------------------------------------------
  # storage_map: var.storage list → map keyed by SA name
  #
  # Input  (var.storage): list of SA objects, each with name, queues, containers, paths
  # Output: { "leifadlsraw" => { name, queues, containers, paths }, ... }
  #
  # Used by:
  #   - azurerm_storage_account.sa          (for_each — one SA per entry)
  #   - azurerm_eventgrid_system_topic.topic (for_each — one topic per SA)
  #   - azurerm_role_assignment.sp_blob_contributor / sp_queue_contributor
  #   - azurerm_role_assignment.me_blob_owner / me_queue_contributor
  #   - time_sleep.rbac_wait (via me_blob_owner dependency)
  # ---------------------------------------------------------------------------
  storage_map = { for sa in var.storage : sa.name => sa }

  # ---------------------------------------------------------------------------
  # queue_map: all queues across all SAs, flattened into a single map
  #
  # Input  (var.storage[*].queues): each SA has a list of { name, type } queue objects
  #         where type is either "queue" (normal event queue) or "dlq" (dead-letter queue)
  # Output: map keyed by "sa_name::queue_name" to avoid collisions across SAs
  #   {
  #     "leifadlsraw::raw-events"      => { sa_name = "leifadlsraw",     queue_name = "raw-events",     queue_type = "queue" }
  #     "leifadlsraw::raw-dlq"         => { sa_name = "leifadlsraw",     queue_name = "raw-dlq",        queue_type = "dlq"   }
  #     "leifadlscurated::curated-events" => { sa_name = "leifadlscurated", queue_name = "curated-events", queue_type = "queue" }
  #     "leifadlscurated::curated-dlq"   => { sa_name = "leifadlscurated", queue_name = "curated-dlq",    queue_type = "dlq"   }
  #   }
  #
  # Used by:
  #   - azurerm_storage_queue.queue          (for_each — creates every queue)
  #   - azurerm_role_assignment.eg_queue_sender (filtered to type == "queue")
  #   - azurerm_role_assignment.me_dlq_reader  (filtered to type == "dlq")
  # ---------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------
  # sa_event_queue: SA name → the single "queue"-typed queue name for that SA
  #
  # Each SA is expected to have exactly one queue with type == "queue"; this local
  # extracts that name so event subscriptions can reference it directly without
  # needing to filter queue_map at the resource level.
  #
  # Output:
  #   {
  #     "leifadlsraw"     => "raw-events"
  #     "leifadlscurated" => "curated-events"
  #   }
  #
  # Used by:
  #   - azurerm_eventgrid_event_subscription.blob_created
  #     (storage_queue_endpoint.queue_name — the destination queue for BlobCreated events)
  # ---------------------------------------------------------------------------
  sa_event_queue = {
    for sa in var.storage :
    sa.name => [for q in sa.queues : q.name if q.type == "queue"][0]
  }

  # ---------------------------------------------------------------------------
  # adls_module_map: per-SA map for the (currently commented-out) container/path module
  #
  # Restructures var.storage into the shape expected by the adls_container_and_paths
  # module — grouping containers and paths under their parent SA name.
  #
  # Output:
  #   {
  #     "leifadlsraw" => { sa_name = "leifadlsraw", containers = [...], paths = [...] }
  #     ...
  #   }
  #
  # Used by:
  #   - module.adls_container_and_paths (for_each — currently commented out in sa.tf)
  # ---------------------------------------------------------------------------
  adls_module_map = {
    for sa in var.storage : sa.name => {
      sa_name    = sa.name
      containers = sa.containers
      paths      = sa.paths
    }
  }
}