terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Every argument and resource used by this module exists in azurerm 3.0,
      # 4.x and 5.x, so the 3.0 floor is real rather than aspirational.
      # The upper bound stops the next major release (6.0) from silently breaking
      # consumers who do not commit a dependency lock file (module callers
      # normally do not).
      version = ">= 3.0, < 6.0"
    }
  }
}
