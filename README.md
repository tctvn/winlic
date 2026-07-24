# winlic

## Main Features

- Check Windows version and detailed license information.
- Retrieve BIOS/OEM product keys.
- Remove or reset the current Windows license.
- KMS activation support (install keys, set KMS servers, and activate).
- Edition conversion (easily upgrade your Windows edition, prepare for a downgrade via Registry changes, or auto-detect BIOS key to restore edition).
- Automatically requests Administrator privileges.

## Quick Installation Guide

**Method 1: Using Windows PowerShell**
Just open Windows PowerShell (run as Administrator if needed) and copy/paste the following command:

```powershell
irm https://raw.githubusercontent.com/tctvn/winlic/main/winlic.ps1 | iex
```

**Method 2: Using the Run Dialog (Win + R)**
Press `Windows + R` on your keyboard, paste the following command, and hit Enter:

```powershell
powershell -nop -c "irm https://raw.githubusercontent.com/tctvn/winlic/main/winlic.ps1 | iex"
```

> **Note:** The `irm` (Invoke-RestMethod) command downloads the file content, and `iex` (Invoke-Expression) executes that content immediately.

## Disclaimer
This tool is intended solely to assist with Windows licensing operations. The author is not responsible for any misuse or illegal use of this tool. We strongly encourage users to purchase a genuine Windows license to support the developers.
