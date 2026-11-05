# terraform-azurerm-sql-database

Terraform module that manages an [Azure](https://azure.microsoft.com/) SQL
database together with the logical server that hosts it. It creates a hardened
server (TLS 1.2, public access disabled, transparent data encryption managed
explicitly) and a single database with a configurable SKU, collation and size.

## Usage

```hcl
module "sql_database" {
  source = "github.com/moveeeax/terraform-azurerm-sql-database?ref=v1.0.0"

  server_name         = "prod-sqlsrv01"
  database_name       = "appdb"
  resource_group_name = "prod-rg"
  location            = "eastus"

  administrator_login          = "sqladmin"
  administrator_login_password = var.db_password
  sku_name                     = "GP_S_Gen5_2"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

`administrator_login_password` has no default. Supply it from a secret store
(Key Vault, `TF_VAR_db_password`, your CI's secret mechanism) — never from a
`.tfvars` file in the repository.

A runnable example lives in [`examples/basic`](examples/basic).

## Security posture

| Behaviour                     | Default                                                     |
|-------------------------------|-------------------------------------------------------------|
| Public network access         | Disabled                                                    |
| Minimum TLS version           | `1.2`; `"Disabled"` is rejected by input validation         |
| Transparent data encryption   | Managed by this module with the service-managed key         |
| Firewall rules                | **None** — the module creates no `azurerm_mssql_firewall_rule` |

The module deliberately creates **no firewall rules**. In particular it does not
create the widely copied "allow Azure services" rule
(`start_ip_address = "0.0.0.0"`, `end_ip_address = "0.0.0.0"`): despite the name,
that rule admits resources in *every* Azure tenant, not only your own. If you
need public reachability, set `public_network_access_enabled = true` and add
narrowly scoped `azurerm_mssql_firewall_rule` or
`azurerm_mssql_virtual_network_rule` resources alongside the module. Private
endpoints are the better option.

### Not managed by this module

Server auditing (`azurerm_mssql_server_extended_auditing_policy`) and Microsoft
Defender for SQL / threat detection
(`azurerm_mssql_server_security_alert_policy`) are **not** created here. Both
need a storage account or Log Analytics workspace — and, for managed-identity
auth, an identity on the server — that this module does not own, and Defender
for SQL is separately billed. Attach them to the exported `server_id`:

```hcl
resource "azurerm_mssql_server_security_alert_policy" "this" {
  resource_group_name  = "prod-rg"
  server_name          = "prod-sqlsrv01"
  state                = "Enabled"
  # azurerm 5.x name; on azurerm 3.x/4.x the argument is `email_account_admins`.
  email_account_admins_enabled = true
}
```

## Requirements

| Name      | Version        |
|-----------|----------------|
| terraform | >= 1.5         |
| azurerm   | >= 3.0, < 6.0  |

The azurerm constraint is bounded on both ends: every argument used here exists
in 3.0, 4.x and 5.x (azurerm 5.0.0 was released on 2026-07-27), and the upper
bound keeps the next major release from breaking callers who do not commit a
dependency lock file. CI validates and tests against the 3.0.0 floor and the
latest 5.x release.

Running the test suite (`terraform test`) additionally needs Terraform or
OpenTofu >= 1.7 for `mock_provider`. That is a contributor requirement only —
consumers still only need 1.5.

## Inputs

| Name                            | Description                                                       | Type          | Default                          | Required |
|---------------------------------|-------------------------------------------------------------------|---------------|----------------------------------|:--------:|
| `server_name`                   | Name of the SQL logical server. Globally unique.                  | `string`      | n/a                              |   yes    |
| `database_name`                 | Name of the database created on the server.                       | `string`      | n/a                              |   yes    |
| `resource_group_name`           | Name of the resource group in which to create the resources.      | `string`      | n/a                              |   yes    |
| `location`                      | Azure region in which to create the resources.                    | `string`      | n/a                              |   yes    |
| `server_version`                | Version of the SQL logical server. `"2.0"` or `"12.0"`.           | `string`      | `"12.0"`                         |    no    |
| `administrator_login`           | Administrator login name. Reserved logins are rejected.           | `string`      | `"sqladmin"`                     |    no    |
| `administrator_login_password`  | Administrator password for the SQL server (sensitive, min 8 chars). | `string`    | n/a                              |   yes    |
| `minimum_tls_version`           | Minimum TLS version. Only `"1.2"` is accepted (azurerm 5.x rejects older values). | `string`      | `"1.2"`                          |    no    |
| `public_network_access_enabled` | Whether the SQL server is reachable over the public internet.     | `bool`        | `false`                          |    no    |
| `sku_name`                      | SKU of the database.                                              | `string`      | `"S0"`                           |    no    |
| `collation`                     | Collation of the database.                                        | `string`      | `"SQL_Latin1_General_CP1_CI_AS"` |    no    |
| `max_size_gb`                   | Maximum size of the database in gigabytes (whole number >= 1).    | `number`      | `32`                             |    no    |
| `zone_redundant`                | Whether the database is zone-redundant.                           | `bool`        | `false`                          |    no    |
| `tags`                          | Map of tags applied to the server and database.                   | `map(string)` | `{}`                             |    no    |

## Outputs

| Name            | Description                                        |
|-----------------|----------------------------------------------------|
| `server_id`     | ID of the SQL logical server.                      |
| `server_fqdn`   | Fully qualified domain name of the SQL server.     |
| `database_id`   | ID of the database.                                |
| `database_name` | Name of the database.                              |

## Development

```sh
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform test        # mocked provider: no Azure credentials, no network
tflint --recursive
```

## License

[MIT](LICENSE)
