# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `azuread_administrator` input: sets a Microsoft Entra ID administrator on the
  server (`login_username`, `object_id`, optional `tenant_id`).
  `azuread_authentication_only` defaults to `false`, so SQL logins keep working
  unless it is turned on. `object_id` and `tenant_id` are checked to be GUIDs.
- `administrator_login_password` is now optional when
  `azuread_authentication_only = true`; the server is then created without a
  SQL administrator. In every other case a missing password fails the plan.

## [1.1.0] - 2026-11-05

### Changed

- Allow azurerm 5.x (`>= 3.0, < 6.0`).
- Breaking: `minimum_tls_version` accepts only `"1.2"`.
- CI: pin tflint.

## [1.0.0]

Initial release (`v0.1.0` points at the same commit).

[Unreleased]: https://github.com/moveeeax/terraform-azurerm-sql-database/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/moveeeax/terraform-azurerm-sql-database/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/moveeeax/terraform-azurerm-sql-database/releases/tag/v1.0.0
