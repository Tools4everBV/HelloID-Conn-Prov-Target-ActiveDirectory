# Built-in Scripts

This folder contains PowerShell scripts used in the built-in Microsoft Active Directory (AD) connector for HelloID Provisioning. These scripts are automatically triggered during specific actions such as Create, Enable, Update, Disable, and Post-actions. You can customize them to reflect your internal structure and logic.

---

## Scripts

### `uniquenessCheck.ps1`
- **Description:** Checks if key user attributes like `sAMAccountName`, `userPrincipalName`, `mail`, and `proxyAddresses` are unique in Active Directory.
- **Use Case:** Use when HelloID's default uniqueness check isn't flexible enough—for example, when you want to sync `sAMAccountName` and `cn` separately from `mail` and `UPN`.

> **Note:** The built-in uniqueness check should not be used together with this script. You must choose one or the other. If you opt to use this script, make sure to deselect all the fields from the "unique fields" section that you want to check with the script.  
>  
> While it’s technically possible to use both, for example, by selecting `userPrincipalName`, `mail`, and `proxyAddresses` for the built-in check and using this script for `commonName` and `sAMAccountName`, it's recommended to use only one method. This ensures greater clarity and simplicity in your configuration.


---

## `orgUnit` Folder

These scripts determine which Organizational Unit (OU) a user should be placed in during specific lifecycle events.

### `initialContainer.ps1`
- **Description:** Calculates the OU where a user account should go when it is created.
- **Use Case:** Place new accounts in different OUs based on department or other person attributes.

### `enableContainer.ps1`
- **Description:** Calculates the OU where a user account should go when it is enabled.
- **Use Case:** Useful when enabled users need to be placed in active OUs that differ per department.

### `updateContainer.ps1`
- **Description:** Calculates the OU where a user account should go when it is updated. If the account is enabled, it goes to the active OU; if disabled, to the disabled OU.
- **Use Case:** Keeps users in the correct OU based on their current status and department.

### `disableContainer.ps1`
- **Description:** Calculates the OU where a user account should go when it is disabled.
- **Use Case:** Useful when disabled users need to be placed in active OUs that differ per department.

### `orgUnit.DefaultOUFallback.ps1`
- **Description:** Calculates a target OU based on department and graduation year. If no specific OU is found, it falls back to a default OU.
- **Use Case:** Use this when OUs are structured by department and year, and you want to ensure a fallback OU exists. Especially useful in education or large organizations where users are grouped by year or department.

### `orgUnit.Disable.DynamicLocation.ReferenceExample.ps1`
- **Description:** Calculates the OU based on user location when the account is disabled. Resolves a base OU and searches for a specific OU inside it.
- **Use Case:** Useful in organizations where disabled accounts are organized by geographic location.

### `orgUnit.Enable.DynamicLocation.ReferenceExample.ps1`
- **Description:** Calculates the OU based on user location when the account is enabled. Works the same way as the disable variant but for active accounts.
- **Use Case:** Use when enabled users must be placed in location-specific OUs.

### `orgUnit.Update.DynamicLocation.ReferenceExample.ps1`
- **Description:** Calculates the OU based on both location and account status (enabled or disabled) when the account is updated.
- **Use Case:** Use this when user OU placement depends on both geographic location and whether the account is active or not.

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
