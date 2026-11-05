terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 6.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Supplied at run time, e.g. via TF_VAR_administrator_login_password or a
# secret store. The previous version of this example hard-coded a password
# literal, which is the exact pattern people copy into production.
variable "administrator_login_password" {
  description = "Administrator password for the example SQL server."
  type        = string
  sensitive   = true
}

module "sql_database" {
  source = "../.."

  server_name         = "example-sqlsrv01"
  database_name       = "exampledb"
  resource_group_name = "example-rg"
  location            = "eastus"

  administrator_login          = "sqladmin"
  administrator_login_password = var.administrator_login_password
  sku_name                     = "S0"

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "sql_database_id" {
  value = module.sql_database.database_id
}
