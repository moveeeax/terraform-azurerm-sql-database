variable "server_name" {
  description = "Name of the SQL logical server. Must be globally unique."
  type        = string

  validation {
    # Azure requires 1-63 characters, lowercase letters, digits and hyphens
    # only, and no leading or trailing hyphen. Catching this here fails the
    # plan instead of failing the API call part way through an apply.
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.server_name))
    error_message = "server_name must be 1-63 characters of lowercase letters, digits or hyphens, and may not start or end with a hyphen."
  }
}

variable "database_name" {
  description = "Name of the database created on the server."
  type        = string

  validation {
    condition     = length(var.database_name) >= 1 && length(var.database_name) <= 128
    error_message = "database_name must be between 1 and 128 characters."
  }

  validation {
    condition     = !can(regex("[<>*%&:/\\\\?]", var.database_name))
    error_message = "database_name may not contain any of the characters < > * % & : / \\ ?"
  }
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

  validation {
    condition     = contains(["2.0", "12.0"], var.server_version)
    error_message = "server_version must be either \"2.0\" or \"12.0\"."
  }
}

variable "administrator_login" {
  description = "Administrator login name for the SQL server."
  type        = string
  default     = "sqladmin"

  validation {
    # Azure rejects these logins outright, but only once the create call is
    # already in flight. Rejecting them at plan time is much cheaper.
    condition = !contains(
      ["admin", "administrator", "sa", "root", "dbmanager", "loginmanager", "guest", "public"],
      lower(var.administrator_login)
    )
    error_message = "administrator_login must not be a reserved SQL login (admin, administrator, sa, root, dbmanager, loginmanager, guest, public)."
  }

  validation {
    condition     = length(var.administrator_login) >= 1 && length(var.administrator_login) <= 128
    error_message = "administrator_login must be between 1 and 128 characters."
  }
}

variable "administrator_login_password" {
  description = "Administrator password for the SQL server. Supply it from a secret store or an environment variable, never a committed .tfvars file. Required unless azuread_administrator.azuread_authentication_only is true; the null default exists only for that case."
  type        = string
  sensitive   = true
  default     = null

  validation {
    # Azure's own complexity floor is 8 characters; anything shorter fails the
    # create call rather than the plan. try() turns length(null) into a pass:
    # whether null is allowed is decided by the precondition on the server.
    condition     = try(length(var.administrator_login_password) >= 8, true)
    error_message = "administrator_login_password must be at least 8 characters long."
  }
}

variable "azuread_administrator" {
  description = "Microsoft Entra ID (Azure AD) administrator of the SQL server, usually a group. azuread_authentication_only defaults to false so SQL logins keep working; setting it to true disables every SQL login, including administrator_login, and lets administrator_login_password be omitted. tenant_id defaults to the provider's tenant."
  type = object({
    login_username              = string
    object_id                   = string
    tenant_id                   = optional(string)
    azuread_authentication_only = optional(bool, false)
  })
  default = null

  validation {
    condition     = var.azuread_administrator == null || try(length(var.azuread_administrator.login_username) >= 1, false)
    error_message = "azuread_administrator.login_username must not be empty."
  }

  validation {
    # The provider parses both values as UUIDs only once the API call is made.
    condition = var.azuread_administrator == null || try(alltrue([
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azuread_administrator.object_id)),
      var.azuread_administrator.tenant_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azuread_administrator.tenant_id)),
    ]), false)
    error_message = "azuread_administrator.object_id and tenant_id must be GUIDs."
  }
}

variable "minimum_tls_version" {
  description = "Minimum TLS version accepted by the SQL server. Only \"1.2\" is accepted: azurerm 5.0 rejects \"1.0\", \"1.1\" and \"Disabled\" for azurerm_mssql_server, and the module refuses them on every provider version so the result does not depend on which provider major resolves."
  type        = string
  default     = "1.2"

  validation {
    condition     = var.minimum_tls_version == "1.2"
    error_message = "minimum_tls_version must be \"1.2\". \"1.0\", \"1.1\" and \"Disabled\" are rejected by azurerm 5.x and by this module."
  }
}

variable "public_network_access_enabled" {
  description = "Whether the SQL server is reachable over the public internet. Defaults to false; reach the server over a private endpoint or a service/virtual network rule instead. This module creates no firewall rules, so enabling this alone does not open the server to any address."
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

  validation {
    condition     = var.max_size_gb >= 1 && floor(var.max_size_gb) == var.max_size_gb
    error_message = "max_size_gb must be a whole number of at least 1."
  }
}

variable "zone_redundant" {
  description = "Whether the database is zone-redundant. Not supported on all SKUs."
  type        = bool
  default     = false
}

variable "short_term_retention_days" {
  description = "Point-in-time restore retention of the database in days (1-35). null leaves the Azure default of 7 days in place. The Basic tier allows at most 7."
  type        = number
  default     = null

  validation {
    # The `if d != null` filter keeps the comparisons away from null: `||` does
    # not short-circuit on Terraform 1.5.
    condition     = alltrue([for d in [var.short_term_retention_days] : d >= 1 && d <= 35 && floor(d) == d if d != null])
    error_message = "short_term_retention_days must be a whole number between 1 and 35."
  }
}

variable "long_term_retention" {
  description = "Long-term retention of full backups. weekly, monthly and yearly are ISO 8601 durations such as \"P4W\", \"P12M\" or \"P5Y\"; week_of_year (1-52) picks the weekly backup kept as the yearly one. null configures no long-term retention."
  type = object({
    weekly       = optional(string)
    monthly      = optional(string)
    yearly       = optional(string)
    week_of_year = optional(number)
  })
  default = null

  validation {
    # An empty object would emit an empty block, which the provider rejects
    # with an AtLeastOneOf error that does not name this input.
    condition = var.long_term_retention == null || length([
      for v in [
        try(var.long_term_retention.weekly, null),
        try(var.long_term_retention.monthly, null),
        try(var.long_term_retention.yearly, null),
        try(var.long_term_retention.week_of_year, null),
      ] : v if v != null
    ]) > 0
    error_message = "long_term_retention must set at least one of weekly, monthly, yearly or week_of_year."
  }

  validation {
    condition = alltrue([
      for d in [
        try(var.long_term_retention.weekly, null),
        try(var.long_term_retention.monthly, null),
        try(var.long_term_retention.yearly, null),
      ] : can(regex("^P(T0S|[0-9]+[DWMY])$", d)) if d != null
    ])
    error_message = "long_term_retention weekly, monthly and yearly must be ISO 8601 durations of a single unit, e.g. \"P4W\", \"P12M\", \"P5Y\", or \"PT0S\" for none."
  }

  validation {
    condition     = alltrue([for w in [try(var.long_term_retention.week_of_year, null)] : w >= 1 && w <= 52 && floor(w) == w if w != null])
    error_message = "long_term_retention.week_of_year must be a whole number between 1 and 52."
  }
}

variable "tags" {
  description = "Map of tags applied to the server and database."
  type        = map(string)
  default     = {}
}
