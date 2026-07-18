variable "server_name" {
  description = "Name of the SQL logical server. Must be globally unique."
  type        = string
}

variable "database_name" {
  description = "Name of the database created on the server."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group in which to create the server and database."
  type        = string
}

variable "location" {
  description = "Azure region in which to create the server and database."
  type        = string
}

variable "server_version" {
  description = "Version of the SQL logical server. Typically 12.0."
  type        = string
  default     = "12.0"
}

variable "administrator_login" {
  description = "Administrator login name for the SQL server."
  type        = string
  default     = "sqladmin"
}

variable "administrator_login_password" {
  description = "Administrator password for the SQL server."
  type        = string
  sensitive   = true
}

variable "minimum_tls_version" {
  description = "Minimum TLS version accepted by the SQL server."
  type        = string
  default     = "1.2"
}

variable "public_network_access_enabled" {
  description = "Whether the SQL server is reachable over the public internet."
  type        = bool
  default     = false
}

variable "sku_name" {
  description = "SKU of the database, e.g. Basic, S0 or GP_S_Gen5_2."
  type        = string
  default     = "S0"
}

variable "collation" {
  description = "Collation of the database."
  type        = string
  default     = "SQL_Latin1_General_CP1_CI_AS"
}

variable "max_size_gb" {
  description = "Maximum size of the database in gigabytes."
  type        = number
  default     = 32
}

variable "zone_redundant" {
  description = "Whether the database is zone-redundant. Not supported on all SKUs."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Map of tags applied to the server and database."
  type        = map(string)
  default     = {}
}
