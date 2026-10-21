# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [2.4.0] - 2026-10-21

### Added

- Built-in OU script examples for every setting under *Administration > Organizational unit configuration*, each as a fixed OU and a dynamic OU (based on department) example:
  - `initialContainer.FixedOU.ps1` and `initialContainer.DynamicOU.ps1`
  - `enableContainer.FixedOU.ps1` and `enableContainer.DynamicOU.ps1`
  - `disableContainer.FixedOU.ps1` and `disableContainer.DynamicOU.ps1`
  - `updateContainer.FixedOU.ps1` and `updateContainer.DynamicOU.ps1`
- The update OU examples determine the OU based on the current OU of the account instead of its enabled/disabled state. Accounts that are created disabled no longer end up directly in the disabled OU.
- `CHANGELOG.md`, including the history of previous releases.

### Changed

- All built-in OU scripts follow the same structure: an `$actionMessage` per step, a single `try/catch/finally`, `Write-Information` for every successful step and `Write-Error` instead of `throw`, so the result is always returned (also on failure, with `Success = false`).
- `built-in/README.md` and `README.md` describe the OU scripts per HelloID setting.
- Removed the outdated *Debug* setting from the connection settings in `README.md` (removed from the connector in 2.3.0) and added the *Rename resources* setting.

### Removed

- `initialContainer.ps1`, `enableContainer.ps1`, `disableContainer.ps1` and `updateContainer.ps1`, replaced by the fixed and dynamic examples above.
- `orgUnit.Enable.DynamicLocation.ReferencExample.ps1`, `orgUnit.Disable.DynamicLocation.ReferencExample.ps1` and `orgUnit.Update.DynamicLocation.ReferencExample.ps1`. The update example determined the OU based on the enabled/disabled state of the account. Use the dynamic examples above and change the attribute the OU is based on (for example the location).
- `orgUnit.DefaultOUFallback.ps1`, an education-specific example based on department and graduation year.

## [2.3.2] - 2025-11-26

### Fixed

- Correlation value in `create.ps1` is now taken from `personFieldValue` instead of `accountFieldValue`.

### Changed

- Updated `INFO_NL.md`.

## [2.3.1] - 2025-09-12

### Changed

- Performance improvements in `permissions/groups/importSubPermission.ps1`.

### Added

- `INFO_DE.md` (German information).

## [2.3.0] - 2025-08-08

### Added

- Entitlement import for accounts (`import.ps1`) and sub-permissions (`permissions/groups/importSubPermission.ps1`).

### Changed

- Removed the debug logging setting. `Write-Verbose` is replaced by `Write-Information` in `create.ps1`.
- Updated `README.md` with the supported features.

## [2.2.1] - 2025-06-05

### Added

- HelloID icon URL in `README.md`.

## [2.2.0] - 2025-04-07

### Added

- `built-in/uniquenessCheck.ps1`, a custom uniqueness check with default examples.
- Default OU examples `initialContainer.ps1`, `enableContainer.ps1`, `disableContainer.ps1` and `updateContainer.ps1`.
- `built-in/README.md` describing the built-in scripts.

### Changed

- Moved the `orgUnit` and `postAdAction` scripts to the `built-in` folder.

## [2.1.1] - 2024-12-02

### Fixed

- Resource script (`resources/groups/resources.ps1`) when multiple groups are found for the same resource. An error is now returned.
- Correlation property and value handling in `permissions/groups/subPermission.ps1`.

## [2.1.0] - 2024-11-22

### Added

- Renaming of resources, enabled with the new *Rename resources* setting.

## [2.0.0] - 2024-08-22

### Added

- Provisioning PowerShell V2 connector: `create.ps1`, `fieldMapping.json`, `configuration.json`, `permissions/groups/subPermission.ps1` and `resources/groups/resources.ps1`.
- `INFO_FR.md` (French information).

### Changed

- Replaced the PowerShell V1 scripts (`create.correlate.ps1`, `update.ps1`, `dynamicPermission.*` and `resources.Groups.*`) by their V2 counterparts.
- Moved the `orgUnit` and `postAdAction` examples to separate folders.

### Fixed

- The `Server` parameter was missing at `Set-ADUser`.

## [1.0.0] - 2024-01-09

### Added

- Initial release of the connector as a Provisioning PowerShell V1 connector, based on the existing history of this repository, including:
  - account scripts (`create.ps1`, `create.correlate.ps1` and `update.ps1`)
  - dynamic permissions for groups and home directories (`dynamicPermission.*`) and group resources (`resources.Groups.*`)
  - OU scripts for the initial, enable, disable and update action (`orgUnit.*`)
  - post AD action examples (`postAdAction.*`), such as resetting the password and updating names
  - `AutomationTasks/DeleteDisabledUsers` and `Reports/Report.employeeId.ps1`
  - `INFO_NL.md` (Dutch information), `Icon.png` and `Logo.png`
