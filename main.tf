locals {
  azuread_only = try(var.azuread_administrator.azuread_authentication_only, false)

  # Whether a password was given is not itself a secret. Unwrapping the boolean
  # keeps administrator_login from being shown as (sensitive) in every plan.
  password_set = nonsensitive(var.administrator_login_password != null)

  # Entra-only server created without a SQL administrator password.
  sql_admin_omitted = local.azuread_only && !local.password_set
}

resource "azurerm_mssql_server" "this" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  version = var.server_version

  # With Entra-only authentication and no password, the server is created
  # without a SQL administrator at all. In every other case the login is passed
  # through unchanged, so existing servers keep exactly the plan they had.
  administrator_login           = local.sql_admin_omitted ? null : var.administrator_login
  administrator_login_password  = var.administrator_login_password
  minimum_tls_version           = var.minimum_tls_version
  public_network_access_enabled = var.public_network_access_enabled

  dynamic "azuread_administrator" {
    for_each = var.azuread_administrator == null ? [] : [var.azuread_administrator]

    content {
      login_username              = azuread_administrator.value.login_username
      object_id                   = azuread_administrator.value.object_id
      tenant_id                   = azuread_administrator.value.tenant_id
      azuread_authentication_only = azuread_administrator.value.azuread_authentication_only
    }
  }

  tags = var.tags

  lifecycle {
    # Cross-variable check kept as a precondition because variable validations
    # that reference other variables need Terraform 1.9 and the module supports
    # 1.5.
    precondition {
      condition     = local.password_set || local.azuread_only
      error_message = "var.administrator_login_password must be set unless var.azuread_administrator.azuread_authentication_only is true: without either, nobody can sign in to the server."
    }
  }
}

# Azure turns transparent data encryption on with a service-managed key when a
# logical server is created, but Terraform does not track that unless the
# setting is declared. Declaring it makes encryption at rest explicit and lets
# `terraform plan` report drift if TDE is ever changed outside of Terraform.
resource "azurerm_mssql_server_transparent_data_encryption" "this" {
  server_id = azurerm_mssql_server.this.id
}

resource "azurerm_mssql_database" "this" {
  name      = var.database_name
  server_id = azurerm_mssql_server.this.id

  sku_name       = var.sku_name
  collation      = var.collation
  max_size_gb    = var.max_size_gb
  zone_redundant = var.zone_redundant

  # Both blocks are Optional+Computed in the provider. Leaving them out keeps
  # whatever Azure has (7-day point-in-time restore, no long-term retention on
  # a new database), so existing deployments see no change. Removing an input
  # later does not reset the policy either: the last applied value stays.
  dynamic "short_term_retention_policy" {
    for_each = var.short_term_retention_days == null ? [] : [var.short_term_retention_days]

    content {
      retention_days = short_term_retention_policy.value
    }
  }

  dynamic "long_term_retention_policy" {
    for_each = var.long_term_retention == null ? [] : [var.long_term_retention]

    content {
      weekly_retention  = long_term_retention_policy.value.weekly
      monthly_retention = long_term_retention_policy.value.monthly
      yearly_retention  = long_term_retention_policy.value.yearly
      week_of_year      = long_term_retention_policy.value.week_of_year
    }
  }

  tags = var.tags
}
