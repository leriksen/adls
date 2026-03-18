output "tags" {
  value = merge(
    module.globals.tags,
    {
      context = local.as_string[var.subscription]
    }
  )
}

output "purpose" {
  value = local.purpose[var.subscription]
}

output "as_string" {
  value = local.as_string[var.subscription]
}

