terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "sql_database" {
  source = "../.."

  server_name         = "example-sqlsrv01"
  database_name       = "exampledb"
  resource_group_name = "example-rg"
  location            = "eastus"

  administrator_login          = "sqladmin"
  administrator_login_password = "ChangeMe-Example-P4ss!"
  sku_name                     = "S0"

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "sql_database_id" {
  value = module.sql_database.database_id
}
