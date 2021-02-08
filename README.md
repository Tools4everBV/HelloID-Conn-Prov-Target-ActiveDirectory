# HelloID-Conn-Prov-Target-ActiveDirectory

This is a native connector. This repo is for additional tools specific to Active Directory

## Automation Tasks
- Automated Deletion of Accounts
This automation will find disabled AD accounts and set a timestamp for when the account should be deleted. The script then evaluates the timestampes in AD and deletes any accounts that are expired.
