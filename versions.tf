terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Every argument and resource used by this module exists in azurerm 3.0
      # as well as 4.x, so the 3.0 floor is real rather than aspirational.
      # The upper bound stops a future 5.0 major release from silently breaking
      # consumers who do not commit a dependency lock file (module callers
      # normally do not).
      version = ">= 3.0, < 5.0"
    }
  }
}
