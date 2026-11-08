# Test-only requirement: `mock_provider` needs Terraform >= 1.7 (or OpenTofu
# >= 1.7). The module itself still only requires >= 1.5 — do not raise
# `required_version` in versions.tf for this file, that would break consumers.
#
# Everything here runs against a mocked azurerm provider, so no Azure
# credentials and no network access are involved.

mock_provider "azurerm" {
  # The provider parses `server_id` as a real Azure resource ID, so the mock has
  # to hand back something shaped like one instead of a random string. The
  # all-zero subscription GUID is the documented placeholder, not a real
  # subscription.
  mock_resource "azurerm_mssql_server" {
    defaults = {
      id                          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-rg/providers/Microsoft.Sql/servers/example-sqlsrv01"
      fully_qualified_domain_name = "example-sqlsrv01.database.windows.net"
    }
  }
}

variables {
  server_name         = "example-sqlsrv01"
  database_name       = "exampledb"
  resource_group_name = "example-rg"
  location            = "eastus"

  # Not a credential: a syntactically valid dummy consumed only by the mock.
  administrator_login_password = "tftest-dummy-value-not-a-secret"
}

run "defaults_are_hardened" {
  assert {
    condition     = azurerm_mssql_server.this.public_network_access_enabled == false
    error_message = "The SQL server must not be reachable from the public internet by default."
  }

  assert {
    condition     = azurerm_mssql_server.this.minimum_tls_version == "1.2"
    error_message = "The SQL server must require TLS 1.2 by default."
  }

  assert {
    condition     = azurerm_mssql_server.this.administrator_login == "sqladmin"
    error_message = "The default administrator login changed unexpectedly."
  }
}

run "transparent_data_encryption_is_managed" {
  assert {
    condition     = azurerm_mssql_server_transparent_data_encryption.this.server_id == azurerm_mssql_server.this.id
    error_message = "Transparent data encryption must be managed for the server this module creates."
  }

  assert {
    condition     = azurerm_mssql_server_transparent_data_encryption.this.key_vault_key_id == null
    error_message = "Transparent data encryption is expected to use the service-managed key."
  }
}

run "tags_are_applied_to_both_resources" {
  variables {
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = azurerm_mssql_server.this.tags["Environment"] == "test"
    error_message = "Tags must be applied to the SQL server."
  }

  assert {
    condition     = azurerm_mssql_database.this.tags["Environment"] == "test"
    error_message = "Tags must be applied to the database."
  }
}

run "public_access_is_opt_in" {
  variables {
    public_network_access_enabled = true
  }

  assert {
    condition     = azurerm_mssql_server.this.public_network_access_enabled == true
    error_message = "public_network_access_enabled must be wired through to the server."
  }
}

run "rejects_disabled_minimum_tls_version" {
  command = plan
  variables {
    minimum_tls_version = "Disabled"
  }

  expect_failures = [var.minimum_tls_version]
}

run "rejects_legacy_minimum_tls_version" {
  command = plan
  variables {
    minimum_tls_version = "1.1"
  }

  expect_failures = [var.minimum_tls_version]
}

run "rejects_unknown_minimum_tls_version" {
  command = plan
  variables {
    minimum_tls_version = "1.3"
  }

  expect_failures = [var.minimum_tls_version]
}

run "rejects_reserved_administrator_login" {
  command = plan
  variables {
    administrator_login = "Admin"
  }

  expect_failures = [var.administrator_login]
}

run "rejects_short_administrator_password" {
  command = plan
  variables {
    administrator_login_password = "short"
  }

  expect_failures = [var.administrator_login_password]
}

run "rejects_invalid_server_name" {
  command = plan
  variables {
    server_name = "Example_SQLSrv01"
  }

  expect_failures = [var.server_name]
}

run "rejects_invalid_server_version" {
  command = plan
  variables {
    server_version = "11.0"
  }

  expect_failures = [var.server_version]
}

run "rejects_invalid_database_name" {
  command = plan
  variables {
    database_name = "app/db"
  }

  expect_failures = [var.database_name]
}

run "rejects_fractional_max_size_gb" {
  command = plan
  variables {
    max_size_gb = 0.5
  }

  expect_failures = [var.max_size_gb]
}

# Entra ID administrator (issue #3). The all-zero GUIDs are placeholders, not
# real directory objects.

run "azuread_administrator_is_off_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_mssql_server.this.azuread_administrator) == 0
    error_message = "No Entra ID administrator may be configured unless azuread_administrator is set."
  }

  assert {
    condition     = azurerm_mssql_server.this.administrator_login == "sqladmin"
    error_message = "Existing deployments must keep their SQL administrator login."
  }
}

run "azuread_administrator_keeps_sql_auth_by_default" {
  command = plan

  variables {
    azuread_administrator = {
      login_username = "sql-admins"
      object_id      = "00000000-0000-0000-0000-000000000001"
    }
  }

  assert {
    condition     = azurerm_mssql_server.this.azuread_administrator[0].login_username == "sql-admins"
    error_message = "azuread_administrator.login_username must be wired through to the server."
  }

  assert {
    condition     = azurerm_mssql_server.this.azuread_administrator[0].object_id == "00000000-0000-0000-0000-000000000001"
    error_message = "azuread_administrator.object_id must be wired through to the server."
  }

  assert {
    condition     = azurerm_mssql_server.this.azuread_administrator[0].azuread_authentication_only == false
    error_message = "Entra-only authentication must stay off unless explicitly enabled: it disables every SQL login."
  }

  assert {
    condition     = azurerm_mssql_server.this.administrator_login == "sqladmin"
    error_message = "Adding an Entra ID administrator must not drop the SQL administrator login."
  }
}

run "azuread_only_without_password_omits_sql_admin" {
  command = plan

  variables {
    administrator_login_password = null
    azuread_administrator = {
      login_username              = "sql-admins"
      object_id                   = "00000000-0000-0000-0000-000000000001"
      tenant_id                   = "00000000-0000-0000-0000-000000000002"
      azuread_authentication_only = true
    }
  }

  assert {
    condition     = azurerm_mssql_server.this.azuread_administrator[0].azuread_authentication_only == true
    error_message = "azuread_authentication_only must be wired through to the server."
  }

  assert {
    condition     = azurerm_mssql_server.this.azuread_administrator[0].tenant_id == "00000000-0000-0000-0000-000000000002"
    error_message = "azuread_administrator.tenant_id must be wired through to the server."
  }

  # administrator_login is Optional+Computed, so the mock fills a value in when
  # the module passes null. The local is what decides the null.
  assert {
    condition     = local.sql_admin_omitted == true
    error_message = "An Entra-only server created without a password must not get a SQL administrator login."
  }
}

run "azuread_only_with_password_keeps_login" {
  command = plan

  variables {
    azuread_administrator = {
      login_username              = "sql-admins"
      object_id                   = "00000000-0000-0000-0000-000000000001"
      azuread_authentication_only = true
    }
  }

  # An existing server switched to Entra-only keeps its login in config, so the
  # plan does not try to remove an attribute Azure cannot change.
  assert {
    condition     = azurerm_mssql_server.this.administrator_login == "sqladmin"
    error_message = "A supplied password must keep the SQL administrator login in the configuration."
  }
}

run "rejects_missing_password_without_azuread_only" {
  command = plan

  variables {
    administrator_login_password = null
    azuread_administrator = {
      login_username = "sql-admins"
      object_id      = "00000000-0000-0000-0000-000000000001"
    }
  }

  expect_failures = [azurerm_mssql_server.this]
}

run "rejects_missing_password_without_azuread_administrator" {
  command = plan

  variables {
    administrator_login_password = null
  }

  expect_failures = [azurerm_mssql_server.this]
}

run "rejects_non_guid_azuread_object_id" {
  command = plan

  variables {
    azuread_administrator = {
      login_username = "sql-admins"
      object_id      = "sql-admins"
    }
  }

  expect_failures = [var.azuread_administrator]
}

run "rejects_non_guid_azuread_tenant_id" {
  command = plan

  variables {
    azuread_administrator = {
      login_username = "sql-admins"
      object_id      = "00000000-0000-0000-0000-000000000001"
      tenant_id      = "contoso.onmicrosoft.com"
    }
  }

  expect_failures = [var.azuread_administrator]
}

run "rejects_empty_azuread_login_username" {
  command = plan

  variables {
    azuread_administrator = {
      login_username = ""
      object_id      = "00000000-0000-0000-0000-000000000001"
    }
  }

  expect_failures = [var.azuread_administrator]
}

# Backup retention (issue #4).

run "backup_retention_is_left_to_azure_by_default" {
  command = plan

  # The provider marks both blocks Optional+Computed, so the plan only stays
  # unchanged for existing databases if the module emits neither block.
  assert {
    condition     = length(azurerm_mssql_database.this.short_term_retention_policy) == 0
    error_message = "No short_term_retention_policy block may be emitted unless short_term_retention_days is set."
  }

  assert {
    condition     = length(azurerm_mssql_database.this.long_term_retention_policy) == 0
    error_message = "No long_term_retention_policy block may be emitted unless long_term_retention is set."
  }
}

run "backup_retention_is_wired_through" {
  command = plan

  variables {
    short_term_retention_days = 35
    long_term_retention = {
      weekly       = "P4W"
      monthly      = "P12M"
      yearly       = "P5Y"
      week_of_year = 1
    }
  }

  assert {
    condition     = azurerm_mssql_database.this.short_term_retention_policy[0].retention_days == 35
    error_message = "short_term_retention_days must be wired through to the database."
  }

  assert {
    condition = (
      azurerm_mssql_database.this.long_term_retention_policy[0].weekly_retention == "P4W" &&
      azurerm_mssql_database.this.long_term_retention_policy[0].monthly_retention == "P12M" &&
      azurerm_mssql_database.this.long_term_retention_policy[0].yearly_retention == "P5Y" &&
      azurerm_mssql_database.this.long_term_retention_policy[0].week_of_year == 1
    )
    error_message = "long_term_retention must be wired through to the database."
  }
}

run "long_term_retention_accepts_a_single_field" {
  command = plan

  variables {
    long_term_retention = {
      monthly = "P12M"
    }
  }

  assert {
    condition     = azurerm_mssql_database.this.long_term_retention_policy[0].monthly_retention == "P12M"
    error_message = "A partially filled long_term_retention must still emit the block."
  }

  assert {
    condition     = length(azurerm_mssql_database.this.short_term_retention_policy) == 0
    error_message = "Setting long-term retention alone must not touch point-in-time restore."
  }
}

run "rejects_out_of_range_short_term_retention_days" {
  command = plan
  variables {
    short_term_retention_days = 36
  }

  expect_failures = [var.short_term_retention_days]
}

run "rejects_fractional_short_term_retention_days" {
  command = plan
  variables {
    short_term_retention_days = 7.5
  }

  expect_failures = [var.short_term_retention_days]
}

run "rejects_empty_long_term_retention" {
  command = plan
  variables {
    long_term_retention = {}
  }

  expect_failures = [var.long_term_retention]
}

run "rejects_non_iso8601_long_term_retention" {
  command = plan
  variables {
    long_term_retention = {
      weekly = "4 weeks"
    }
  }

  expect_failures = [var.long_term_retention]
}

run "rejects_out_of_range_week_of_year" {
  command = plan
  variables {
    long_term_retention = {
      yearly       = "P5Y"
      week_of_year = 53
    }
  }

  expect_failures = [var.long_term_retention]
}
