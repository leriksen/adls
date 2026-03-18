output "tags" {
  value = merge(
    module.subscription.tags,
    {
      environment = var.environment
    }
  )
}

output "env_sub" {
  value = local.env_sub[var.environment]
}
