locals {
  # Object ID of the current user (Leif).
  # Used in RBAC role assignments (me_blob_owner, me_queue_contributor, me_dlq_reader)
  # so that the deploying user has direct data-plane access to all storage accounts.
  me = "00e67771-2882-40d1-a0c4-899f624ea97d"

  # ---------------------------------------------------------------------------
  # storage_map: var.storage list → map keyed by sequence_no (as string)
  #
  # Input  (var.storage): list of SA objects, each with sequence_no, queues, containers, paths
  # Output: { "01" => { sequence_no, queues, containers, paths }, "02" => { ... }, ... }
  #
  # Used by:
  #   - azurerm_storage_account.sa          (for_each — one SA per entry)
  #   - azurerm_eventgrid_system_topic.topic (for_each — one topic per SA)
  #   - azurerm_role_assignment.sp_blob_contributor / sp_queue_contributor
  #   - azurerm_role_assignment.me_blob_owner / me_queue_contributor
  #   - time_sleep.rbac_wait (via me_blob_owner dependency)
  # ---------------------------------------------------------------------------
  storage_map = { for sa in var.storage : sa.sequence_no => sa }

  # ---------------------------------------------------------------------------
  # queue_map: all queues across all SAs, flattened into a single map
  #
  # Input  (var.storage[*].queues): each SA has a list of { name, type } queue objects.
  #         Every queue is created regardless of type — type only controls which RBAC
  #         roles are assigned (see role assignments in sa.tf):
  #           "queue" → Storage Queue Data Message Sender granted to the Event Grid
  #                     system topic identity, so EG can deliver BlobCreated events
  #           "dlq"   → Storage Queue Data Reader granted to the current user (local.me)
  #                     for manual inspection of failed/unprocessed messages
  #
  # Output: map keyed by "sa_key::queue_name" to avoid collisions across SAs
  #   {
  #     "01::raw-events"      => { sa_key = "01", queue_name = "raw-events",     queue_type = "queue" }
  #     "01::raw-dlq"         => { sa_key = "01", queue_name = "raw-dlq",        queue_type = "dlq"   }
  #     "02::curated-events"  => { sa_key = "02", queue_name = "curated-events", queue_type = "queue" }
  #     "02::curated-dlq"     => { sa_key = "02", queue_name = "curated-dlq",    queue_type = "dlq"   }
  #   }
  #
  # Used by:
  #   - azurerm_storage_queue.queue             (for_each — creates ALL queues)
  #   - azurerm_role_assignment.eg_queue_sender (filtered to type == "queue" — EG sender role)
  #   - azurerm_role_assignment.me_dlq_reader   (filtered to type == "dlq"   — reader role)
  # ---------------------------------------------------------------------------
  queue_map = {
    for pair in flatten([
      for sa in var.storage : [
        for q in sa.queues : {
          sa_key     = sa.sequence_no
          queue_name = q.name
          queue_type = q.type
        }
      ]
    ]) : "${pair.sa_key}::${pair.queue_name}" => pair
  }

  # ---------------------------------------------------------------------------
  # sa_event_queue: SA key → the event subscription target queue name for that SA
  #
  # Note: this does NOT control which queues are created — all queues are created
  # via queue_map regardless of type. This local only identifies which queue receives
  # BlobCreated events from Event Grid (i.e. the queue with type == "queue").
  # Each SA is expected to have exactly one such queue; [0] will error at plan time
  # if an SA has no "queue"-typed queue.
  #
  # Output: { "01" => "raw-events", "02" => "curated-events" }
  #
  # Used by:
  #   - azurerm_eventgrid_event_subscription.blob_created
  #     (storage_queue_endpoint.queue_name — the destination queue for BlobCreated events)
  # ---------------------------------------------------------------------------
  sa_event_queue = {
    for sa in var.storage :
    sa.sequence_no => [for q in sa.queues : q.name if q.type == "queue"][0]
  }

  # ---------------------------------------------------------------------------
  # snowflake_sp_map: SA key → Snowflake SP object ID, for SAs where it is set
  #
  # Used by:
  #   - azurerm_role_assignment.snowflake_blob_contributor (Storage Blob Data Contributor)
  # ---------------------------------------------------------------------------
  snowflake_sp_map = {
    for sa in var.storage : sa.sequence_no => sa.snowflake_sp
    if sa.snowflake_sp != null
  }

  # ---------------------------------------------------------------------------
  # sa_integration_sp_map: SA key → SA integration SP object ID, for SAs where it is set
  #
  # Used by:
  #   - azurerm_role_assignment.sa_integration_blob_contributor (Storage Blob Data Contributor)
  # ---------------------------------------------------------------------------
  sa_integration_sp_map = {
    for sa in var.storage : sa.sequence_no => sa.sa_integration_sp
    if sa.sa_integration_sp != null
  }

  # ---------------------------------------------------------------------------
  # notification_sp_queue_map: "sa_key::queue_name" → { sp_id, sa_key, queue_name }
  #
  # Flat map of all "queue"-typed queues (not DLQs) on SAs where
  # notification_integration_sp is set. The notification SP needs to read
  # queue messages but must not have access to DLQs.
  #
  # Used by:
  #   - azurerm_role_assignment.notification_sp_queue_contributor (Storage Queue Data Contributor)
  # ---------------------------------------------------------------------------
  notification_sp_queue_map = {
    for pair in flatten([
      for sa in var.storage : [
        for q in sa.queues : {
          sa_key     = sa.sequence_no
          queue_name = q.name
          sp_id      = sa.notification_integration_sp
        }
        if q.type == "queue"
      ]
      if sa.notification_integration_sp != null
    ]) : "${pair.sa_key}::${pair.queue_name}" => pair
  }

  # ---------------------------------------------------------------------------
  # container_map: all containers across all SAs, flattened into a single map
  #
  # Output: map keyed by "sa_key::container_name"
  #   {
  #     "01::landing"     => { sa_key = "01", container_name = "landing",     acl = [] }
  #     "02::deadletter"  => { sa_key = "02", container_name = "deadletter",  acl = [] }
  #     ...
  #   }
  #
  # Used by:
  #   - azurerm_storage_data_lake_gen2_filesystem.container (for_each — creates all containers)
  # ---------------------------------------------------------------------------
  container_map = {
    for pair in flatten([
      for sa in var.storage : [
        for c in sa.containers : {
          sa_key         = sa.sequence_no
          container_name = c.container_name
          acl            = c.acl
        }
      ]
    ]) : "${pair.sa_key}::${pair.container_name}" => pair
  }

  # ---------------------------------------------------------------------------
  # eg_deadletter_map: SA key → SA object, for SAs that have a "deadletter" container
  #
  # Used by:
  #   - azurerm_role_assignment.eg_deadletter_blob_contributor
  #     (Storage Blob Data Contributor on the deadletter container, granted to the
  #      Event Grid system topic managed identity so EG can write failed events to blob)
  # ---------------------------------------------------------------------------
  eg_deadletter_map = {
    for sa in var.storage : sa.sequence_no => sa
    if contains([for c in sa.containers : c.container_name], "deadletter")
  }

  # ---------------------------------------------------------------------------
  # adls_module_map: per-SA map for the (currently commented-out) container/path module
  #
  # Restructures var.storage into the shape expected by the adls_container_and_paths
  # module — grouping containers and paths under their parent SA key.
  #
  # Output:
  #   {
  #     "1" => { sa_key = "1", containers = [...], paths = [...] }
  #     ...
  #   }
  #
  # Used by:
  #   - module.adls_container_and_paths (for_each — currently commented out in sa.tf)
  # ---------------------------------------------------------------------------
  adls_module_map = {
    for sa in var.storage : sa.sequence_no => {
      sa_key     = sa.sequence_no
      containers = sa.containers
      paths      = sa.paths
    }
  }
}