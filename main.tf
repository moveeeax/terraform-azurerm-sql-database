resource "azurerm_mssql_server" "this" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location

  version                       = var.server_version
  administrator_login           = var.administrator_login
  administrator_login_password  = var.administrator_login_password
  minimum_tls_version           = var.minimum_tls_version
  public_network_access_enabled = var.public_network_access_enabled

  tags = var.tags
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

  tags = var.tags
}
