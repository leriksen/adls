data "azurerm_client_config" "current" {}

data "azapi_resource_list" "system_topics" {
  type      = "Microsoft.EventGrid/systemTopics@2022-06-15"
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"

  response_export_values = ["value"]
}
