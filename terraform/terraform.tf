terraform {
  required_version = "~>1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~>0.9"
    }

    # azuredevops = {
    #   source = "microsoft/azuredevops"
    #   version = ">= 0.1.0"
    # }
  }

  backend "local" {
    path = "./terraform.tfstate"
  }

  # cloud {
  #   organization = "leriksen-experiment"
  #   hostname     = "app.terraform.io"
  # }
}
