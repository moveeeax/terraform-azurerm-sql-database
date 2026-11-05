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
