module "globals" {
  source = "../globals"
}

locals {
  env_sub = {
    dev = "NP"
  }
}

module "subscription" {
  source       = "../subscription"
  subscription = local.env_sub[var.environment]
}
