# ---------------------------------------------------------------------------
# RBAC: current user (local.me) — mirrors azdo-sc role assignments
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "me_blob_contributor" {
  for_each = local.snowflake_sp_map

  principal_id         = local.me
  role_definition_name = "Storage Blob Data Contributor"
  scope                = module.sa[each.key].id
}
