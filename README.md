# HelloID-Conn-Prov-Target-ActiveDirectory

| :warning: Warning |
| :---------------- |
| This readme is not updated. This will be done in combination with the import/export file for powershell V2 |

| :warning: Warning |
| :---------------- |
| Not all scripts are converted to powershell V2. Please check the comments in the first 5 rows of the code |

| :warning: Warning |
| :---------------- |
| This script is for the new powershell connector. Make sure to use the mapping and correlation keys like mentionded in this readme. For more information, please read our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) |

<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/activedirectory-logo.png">
</p>
<br />
This is a native connector. This repo is for additional tools specific to Active Directory

## Table of Contents
- [HelloID-Conn-Prov-Target-ActiveDirectory](#helloid-conn-prov-target-activedirectory)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
  - [Setup the PowerShell connector](#setup-the-powershell-connector)
  - [Automation Tasks](#automation-tasks)
- [HelloID Docs](#helloid-docs)

## Getting Started
* Create user account 
* Enable user account
* Disable user account
* Delete user account
* Manage permissions (grant / revoke)
  * Group Membership
  * Home Directory creation


## Setup the PowerShell connector
1. Add a new 'Target System' to HelloID and make sure to import all the necessary files.

    - [ ] configuration.json
    - [ ] create.ps1
    - [ ] dynamicPermission.HomeDirectory.ps1

2. Fill in the required fields on the 'Configuration' tab. 

## Automation Tasks
* **Automated Deletion of Accounts**
  * This automation will find disabled AD accounts and set a timestamp for when the account should be deleted. The script then evaluates the timestamps in AD and deletes any accounts that are expired.


_For more information about our HelloID PowerShell connectors, please refer to our general [Documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) page_

# HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
