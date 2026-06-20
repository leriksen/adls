locals {
  # Object ID of the current user (Leif).
  # Used in RBAC role assignments in my_access.tf.
  me = "00e67771-2882-40d1-a0c4-899f624ea97d"

  # ---------------------------------------------------------------------------
  # storage_map: var.storage list → map keyed by sequence_no (as string)
  #
  # Input  (var.storage): list of SA objects, each with sequence_no, queues, containers, paths
  # Output: { "01" => { sequence_no, queues, containers, paths }, "02" => { ... }, ... }
  #
  # Used by:
  #   - azurerm_storage_account.sa          (for_each — one SA per entry)
  #   - azurerm_role_assignment.sp_blob_contributor / sp_queue_contributor
  #   - azurerm_role_assignment.me_blob_owner / me_queue_contributor
  #   - time_sleep.rbac_wait (via me_blob_owner dependency)
  # ---------------------------------------------------------------------------
  storage_map = { for sa in var.storage : sa.sequence_no => sa }

  # ---------------------------------------------------------------------------
  # sa_resource_id: SA key → lower-cased SA resource ID, constructed from
  # known values so it is always available at plan time.
  # ---------------------------------------------------------------------------
  sa_resource_id = {
    for k in keys(local.storage_map) :
    k => lower("/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.arg.name}/providers/Microsoft.Storage/storageAccounts/${azurerm_resource_group.arg.name}dl${k}")
  }

  # ---------------------------------------------------------------------------
  # system_topics_by_source: maps lower(source resource ID) → system topic name
  #
  # Discovered dynamically via the azapi_resource_list data source. Empty if no
  # system topics exist yet (i.e. first run before topics are manually created).
  # ---------------------------------------------------------------------------
  system_topics_by_source = {
    for topic in try(data.azapi_resource_list.system_topics.output.value, []) :
    lower(topic.properties.source) => topic.name
  }

  # ---------------------------------------------------------------------------
  # system_topic_identities: maps lower(source resource ID) → principal_id
  #
  # Only populated for topics that already have SystemAssigned identity enabled.
  # Used to gate subscription and role assignment creation on identity readiness.
  # ---------------------------------------------------------------------------
  system_topic_identities = {
    for topic in try(data.azapi_resource_list.system_topics.output.value, []) :
    lower(topic.properties.source) => topic.identity.principalId
    if try(topic.identity.type, "None") == "SystemAssigned" && try(topic.identity.principalId, "") != ""
  }

  # ---------------------------------------------------------------------------
  # sa_with_event_subscriptions: storage_map entries for which a matching
  # Event Grid system topic has been discovered in Azure.
  #
  # Used by azapi_update_resource to enable managed identity on the topic.
  # Produces an empty map when storage_map is empty or no topics exist yet.
  # ---------------------------------------------------------------------------
  sa_with_event_subscriptions = {
    for k, v in local.storage_map :
    k => v
    if contains(keys(local.system_topics_by_source), local.sa_resource_id[k])
  }

  # ---------------------------------------------------------------------------
  # sa_with_managed_identity: sa_with_event_subscriptions further filtered to
  # topics whose SystemAssigned managed identity is already active.
  #
  # Gates all downstream EG resources — subscriptions and role assignments are
  # only created once the identity is confirmed enabled. On first run (topic
  # exists but identity not yet enabled) this is empty; on the next run the
  # azapi_update_resource will have enabled the identity and this populates.
  # ---------------------------------------------------------------------------
  sa_with_managed_identity = {
    for k, v in local.sa_with_event_subscriptions :
    k => v
    if contains(keys(local.system_topic_identities), local.sa_resource_id[k])
  }

  # ---------------------------------------------------------------------------
  # system_topic_info: SA key → { id, principal_id } for topics with identity
  #
  # Provides the system topic resource ID and managed identity principal_id
  # without requiring a separate data source lookup per topic.
  # ---------------------------------------------------------------------------
  system_topic_info = {
    for k in keys(local.sa_with_managed_identity) :
    k => {
      name                = local.system_topics_by_source[local.sa_resource_id[k]]
      resource_group_name = azurerm_resource_group.arg.name
      principal_id        = local.system_topic_identities[local.sa_resource_id[k]]
    }
  }

  # ---------------------------------------------------------------------------
  # queue_map: all queues across all SAs, flattened into a single map
  #
  # Input  (var.storage[*].queues): each SA has a list of { name, type } queue objects.
  #         Every queue is created regardless of type — type only controls which RBAC
  #         roles are assigned (see role assignments in sa.tf):
  #           "queue" → Storage Queue Data Message Sender granted to the Event Grid
  #                     system topic identity, so EG can deliver BlobCreated events
  #           "deadletter" → Storage Queue Data Reader granted to the current user (local.me)
  #                         for manual inspection of failed/unprocessed messages
  #
  # Output: map keyed by "sa_key::queue_name" to avoid collisions across SAs
  #   {
  #     "01::raw-events"  => { sa_key = "01", queue_name = "raw-events",  queue_type = "queue"      }
  #     "01::deadletter"  => { sa_key = "01", queue_name = "deadletter",  queue_type = "deadletter" }
  #     "02::curated-events" => { sa_key = "02", queue_name = "curated-events", queue_type = "queue"      }
  #     "02::deadletter"  => { sa_key = "02", queue_name = "deadletter",  queue_type = "deadletter" }
  #   }
  #
  # Used by:
  #   - azurerm_storage_queue.queue             (for_each — creates ALL queues)
  #   - azurerm_role_assignment.eg_queue_sender  (filtered to type == "queue"      — EG sender role)
  #   - azurerm_role_assignment.me_dlq_reader    (filtered to type == "deadletter" — reader role)
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
  # sa_event_queue: SA key → the full "queue"-typed queue object for that SA
  #
  # Note: this does NOT control which queues are created — all queues are created
  # via queue_map regardless of type. This local only identifies which queue receives
  # BlobCreated events from Event Grid (i.e. the queue with type == "queue").
  # Each SA is expected to have exactly one such queue; [0] will error at plan time
  # if an SA has no "queue"-typed queue.
  #
  # Output: { "01" => { name, type, included_event_types, subject_filter, advanced_filter }, ... }
  #
  # Used by:
  #   - module.eg_subscription (queue_name, included_event_types, subject_filter, advanced_filter)
  # ---------------------------------------------------------------------------
  sa_event_queue = {
    for sa in var.storage :
    sa.sequence_no => [for q in sa.queues : q if q.type == "queue"][0]
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
  # eg_deadletter_queues: SA key → SA object, for SAs that have a "deadletter"-typed queue
  #
  # Used by:
  #   - azurerm_role_assignment.eg_deadletter_blob_contributor
  #     (Storage Blob Data Contributor on the deadletter container, granted to the
  #      Event Grid system topic managed identity so EG can write failed events to blob)
  # ---------------------------------------------------------------------------
  eg_deadletter_queues = {
    for sa in var.storage : sa.sequence_no => sa
    if contains([for q in sa.queues : q.type], "deadletter") && contains(keys(local.sa_with_managed_identity), sa.sequence_no)
  }

  # ---------------------------------------------------------------------------
  # adls_module_map: per-SA map keyed by sequence_no
  #
  # Output:
  #   {
  #     "01" => { sequence_no = "01", containers = [...], paths = [...] }
  #     "02" => { sequence_no = "02", containers = [...], paths = [...] }
  #   }
  #
  # Used by:
  #   - module.adls_container_and_paths (for_each — currently commented out in sa.tf)
  # ---------------------------------------------------------------------------
  adls_module_map = {
    for sa in var.storage : sa.sequence_no => {
      sequence_no = sa.sequence_no
      containers  = sa.containers
      paths       = sa.paths
    }
  }

  # ---------------------------------------------------------------------------
  # sa_with_queues: storage_map filtered to SAs that have at least one queue
  #
  # Used by:
  #   - module.sa_queue (for_each — only provision queue module where queues exist)
  # ---------------------------------------------------------------------------
  sa_with_queues = { for k, v in local.storage_map : k => v if length(v.queues) > 0 }

  # ---------------------------------------------------------------------------
  # event_queues: queue_map filtered to queues of type "queue"
  #
  # Used by:
  #   - azurerm_role_assignment.eg_queue_sender (EG identity → Queue Data Message Sender)
  # ---------------------------------------------------------------------------
  event_queues = { for k, v in local.queue_map : k => v if v.queue_type == "queue" && contains(keys(local.sa_with_managed_identity), v.sa_key) }

  # ---------------------------------------------------------------------------
  # deadletter_queues: queue_map filtered to queues of type "deadletter"
  #
  # Used by:
  #   - azurerm_role_assignment.me_dlq_reader (current user → Queue Data Reader)
  # ---------------------------------------------------------------------------
  deadletter_queues = { for k, v in local.queue_map : k => v if v.queue_type == "deadletter" }


  # ---------------------------------------------------------------------------
  # pep_approve_map: SAs with a pep_connection where approve == true
  # pep_deny_map:    SAs with a pep_connection where approve == false
  # ---------------------------------------------------------------------------
  pep_approve_map = { for k, v in local.storage_map : k => v if v.pep_connection != null && v.pep_connection.approve == true }
  pep_deny_map    = { for k, v in local.storage_map : k => v if v.pep_connection != null && v.pep_connection.approve == false }

  # ---------------------------------------------------------------------------
  # sftp_configs: SA key → resolved sftp_users list, for SAs that define them.
  # Public keys are read from disk at plan time via file().
  #
  # Used by:
  #   - module.sftp_local_users (for_each — one instance per SFTP-enabled SA)
  # ---------------------------------------------------------------------------
  sftp_configs = {
    for s in var.storage : s.sequence_no => [
      for u in s.sftp_users : {
        sequence_number         = u.sequence_number
        home_directory          = u.home_directory
        ssh_key_enabled         = u.ssh_key_enabled
        allow_acl_authorization = u.allow_acl_authorization
        permission_scopes       = u.permission_scopes
        ssh_authorized_keys = [
          for k in u.ssh_authorized_keys : {
            key         = trimspace(file(k.public_key_path))
            description = k.description
          }
        ]
      }
    ]
    if length(s.sftp_users) > 0
  }
}