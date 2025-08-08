# HelloID-Conn-Prov-Target-ActiveDirectory

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-ActiveDirectory/blob/main/Logo.png?raw=true">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-ActiveDirectory](#helloid-conn-prov-target-activedirectory)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported  features](#supported--features)
  - [Getting started](#getting-started)
    - [HelloID Icon URL](#helloid-icon-url)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
      - [Correlation configuration](#correlation-configuration)
      - [Field mapping](#field-mapping)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-ActiveDirectory_ is a _target_ connector. This connector is used to dynamically add Active Directory groups to Active Directory users by assigning subPermissions within HelloID.

## Supported  features

The following features are available:

| Feature                                   | Supported | Actions                 | Remarks                               |
| ----------------------------------------- | --------- | ----------------------- | ------------------------------------- |
| **Account Lifecycle**                     | ✅         | Correlate               |                                       |
| **Permissions**                           | ✅         | Retrieve, Grant, Revoke | Only sub-permissions                  |
| **Resources**                             | ✅         | Create, Update          |                                       |
| **Entitlement Import: Accounts**          | ✅         | -                       | Only for correlation                  |
| **Entitlement Import: Permissions**       | ✅         | -                       | Only sub-permissions                  |
| **Governance Reconciliation Resolutions** | ✅         | -                       | No actions because of sub-permissions |

## Getting started

### HelloID Icon URL
URL of the icon used for the HelloID Provisioning target system.

```
https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-ActiveDirectory/refs/heads/main/Icon.png
```
### Provisioning PowerShell V2 connector

#### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _ActiveDirectory_ to a person in _HelloID_.

Please rename the field mapping correlation field to the correlation field used in the dependent system. 
Most likely the built-in Microsoft Active Directory target system.

To properly setup the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value                             |
    | ------------------------- | --------------------------------- |
    | Enable correlation        | `True`                            |
    | Person correlation field  | `PersonContext.Person.ExternalId` |
    | Account correlation field | `employeeId`                      |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

#### Field mapping

The field mapping can be imported by using the [_fieldMapping.json_](./fieldMapping.json) file.

### Connection settings

The following settings can be configured.

| Setting                 | Description                                                                     | Mandatory |
| ----------------------- | ------------------------------------------------------------------------------- | --------- |
| Fixed domain controller | Optionally fill in a domain controller if a fixed domain controller is required |           |
| Debug                   | Creates extra logging for debug purposes                                        |           |

### Prerequisites
The powershell ActiveDirectory module is required for this target connector.

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

