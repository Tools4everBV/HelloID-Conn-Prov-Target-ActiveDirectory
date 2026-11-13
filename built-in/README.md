# Built-in Scripts

This folder contains PowerShell scripts used in the built-in Microsoft Active Directory (AD) connector for HelloID Provisioning. These scripts are automatically triggered during specific actions such as Create, Enable, Update, Disable, and Post-actions. You can customize them to reflect your internal structure and logic.

---

## Scripts

### `uniquenessCheck.ps1`
- **Description:** Checks if key user attributes like `sAMAccountName`, `userPrincipalName`, `mail`, and `proxyAddresses` are unique in Active Directory.
- **Use Case:** Use when HelloID's default uniqueness check isn't flexible enough—for example, when you want to sync `sAMAccountName` and `cn` separately from `mail` and `UPN`.

> [!NOTE]
> The built-in uniqueness check should not be used together with this script. You must choose one or the other. If you opt to use this script, make sure to deselect all the fields from the "unique fields" section that you want to check with the script.  
>  
> While it’s technically possible to use both, for example, by selecting `userPrincipalName`, `mail`, and `proxyAddresses` for the built-in check and using this script for `commonName` and `sAMAccountName`, it's recommended to use only one method. This ensures greater clarity and simplicity in your configuration.


---

## `orgUnit` Folder

These scripts determine which Organizational Unit (OU) a user should be placed in during specific lifecycle events. They are examples: adjust the OUs (and, for the dynamic examples, the attribute they are based on) to the implementation.

The scripts are named after the setting in HelloID (*Administration > Organizational unit configuration*) they are meant for, followed by the kind of example:

| Script prefix | HelloID setting |
|---|---|
| `initialContainer` | Initial container |
| `enableContainer` | Move account when the account enable action is performed |
| `disableContainer` | Move account when the account disable action is performed |
| `updateContainer` | Move account when the account update action is performed |

Every setting has two examples:
- **`.FixedOU.ps1`:** every account goes to the same, fixed OU.
- **`.DynamicOU.ps1`:** the OU is determined with a switch, by default based on the department of the primary contract.

All scripts return the OU as `OrganizationalUnit` (canonicalName, name, objectGuid) and always return a result, also on failure (with `Success = false`).

### `initialContainer.*`, `enableContainer.*` and `disableContainer.*`
- **Description:** Calculate the OU where a user account should go when it is created, enabled or disabled. The three settings work the same way and only differ in the OU: the examples for initial and enable use an enabled OU, the examples for disable use a disabled OU.
- **Use Case:** Place accounts in a fixed OU, or in a different OU per department or other person attribute.

### `updateContainer.*`
- **Description:** Calculates the OU where a user account should go when it is updated, using an enabled OU and a disabled OU (fixed, or per department). It uses the current OU of the account, not its enabled/disabled state: an account that is already in the disabled OU stays in (or is placed in) the disabled OU, otherwise it goes to the enabled OU.
- **Use Case:** Use this when accounts can also be created disabled. Basing the OU on the enabled/disabled state would put those accounts directly in the disabled OU.

---

## `postAdAction` Folder

These scripts run after the main AD action has been completed (Create, Enable, Update, or Disable).

### `postAdAction.create.UpdateADAccountMsExchHideFromAddressLists.ps1`
- **Description:** Updates the `msExchHideFromAddressLists` attribute after account creation.
- **Use Case:** Hide a user’s mailbox from Exchange address lists when not using the built-in Exchange integration or when the options of the built-in Exchange integration do not suffice.

### `postAdAction.disable.UpdateADAccountDescription.ps1`
- **Description:** Updates the `description` field in AD after the account is disabled, appending a timestamp and reason.
- **Use Case:** Useful for audit trails or tracking when and why an account was disabled.

### `postAdAction.enable.ResetPassword.ps1`
- **Description:** Generates a new random password and resets it for the user after the account is enabled.
- **Use Case:** Provide a fresh password as part of the enablement process, making it available for the notifications.

### `postAdAction.enable.UpdateADAccountDescription.ps1`
- **Description:** Updates the `description` field in AD after the account is enabled, appending a timestamp and reason.
- **Use Case:** Add clarity to AD records by documenting HelloID enablement.

### `postAdAction.update.UpdateADAccountNames.ps1`
- **Description:** Updates the `sAMAccountName`, `userPrincipalName`, and `email` if the user's first or last name changes.
- **Use Case:** Use when updates should only be performed if specific properties, such as givenName or surName, have changed, and should not trigger updates when other properties, like department or title, are modified.

---

## Getting Started

To use these scripts:
- Make sure your HelloID Provisioning environment is properly configured.
- Customize the logic to reflect your organization's structure.
- Test in a non-production environment before deploying to production.

---

> ⚠️ Note: These scripts are templates and examples. Review and adapt them to your specific environment before use.
