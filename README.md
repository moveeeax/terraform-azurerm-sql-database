# terraform-azurerm-sql-database

Terraform module that manages an [Azure](https://azure.microsoft.com/) SQL
database together with the logical server that hosts it. It creates a hardened
server (TLS 1.2, public access disabled by default) and a single database with
a configurable SKU, collation and size.

## Usage

```hcl
module "sql_database" {
  source = "github.com/moveeeax/terraform-azurerm-sql-database"

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

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| azurerm   | >= 3.0   |

## Inputs

| Name                            | Description                                                       | Type          | Default                          | Required |
|---------------------------------|-------------------------------------------------------------------|---------------|----------------------------------|:--------:|
| `server_name`                   | Name of the SQL logical server. Globally unique.                  | `string`      | n/a                              |   yes    |
| `database_name`                 | Name of the database created on the server.                       | `string`      | n/a                              |   yes    |
| `resource_group_name`           | Name of the resource group in which to create the resources.      | `string`      | n/a                              |   yes    |
| `location`                      | Azure region in which to create the resources.                    | `string`      | n/a                              |   yes    |
| `server_version`                | Version of the SQL logical server.                                | `string`      | `"12.0"`                         |    no    |
| `administrator_login`           | Administrator login name for the SQL server.                      | `string`      | `"sqladmin"`                     |    no    |
| `administrator_login_password`  | Administrator password for the SQL server (sensitive).            | `string`      | n/a                              |   yes    |
| `minimum_tls_version`           | Minimum TLS version accepted by the SQL server.                   | `string`      | `"1.2"`                          |    no    |
| `public_network_access_enabled` | Whether the SQL server is reachable over the public internet.     | `bool`        | `false`                          |    no    |
| `sku_name`                      | SKU of the database.                                              | `string`      | `"S0"`                           |    no    |
| `collation`                     | Collation of the database.                                        | `string`      | `"SQL_Latin1_General_CP1_CI_AS"` |    no    |
| `max_size_gb`                   | Maximum size of the database in gigabytes.                        | `number`      | `32`                             |    no    |
| `zone_redundant`                | Whether the database is zone-redundant.                           | `bool`        | `false`                          |    no    |
| `tags`                          | Map of tags applied to the server and database.                   | `map(string)` | `{}`                             |    no    |

## Outputs

| Name            | Description                                        |
|-----------------|----------------------------------------------------|
| `server_id`     | ID of the SQL logical server.                      |
| `server_fqdn`   | Fully qualified domain name of the SQL server.     |
| `database_id`   | ID of the database.                                |
| `database_name` | Name of the database.                              |

## License

[MIT](LICENSE)
