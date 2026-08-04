# Install Command Code GUI

## One-command installation

macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/CommandCodeAI/desktop/main/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/CommandCodeAI/desktop/main/install.ps1 | iex
```

## What the installers do

1. Detect the operating system and supported CPU architecture.
2. Read the newest release from `CommandCodeAI/desktop`.
3. Select the matching `.dmg`, `.deb`, or `.exe`.
4. Verify the SHA-256 digest published by GitHub.
5. Install and open Command Code.

The scripts fail without installing anything when a matching verified artifact
is unavailable.

macOS releases are signed with an Apple Developer ID and notarized. The script
verifies the signature and Gatekeeper assessment and stops without installing
if either check fails - it never removes quarantine or modifies a build.
On Windows, the script asks before opening an unsigned but SHA-256-verified
installer; that temporary prompt disappears when Windows production signing is
enabled.

The source is public:

- [install.sh](install.sh)
- [install.ps1](install.ps1)

## Install a specific version

macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/CommandCodeAI/desktop/main/install.sh | COMMANDCODE_VERSION=0.1.3 bash
```

Windows PowerShell:

```powershell
$env:COMMANDCODE_VERSION="0.1.3"; irm https://raw.githubusercontent.com/CommandCodeAI/desktop/main/install.ps1 | iex
```

## Getting help

If installation fails, [open a bug report](https://github.com/CommandCodeAI/desktop/issues/new/choose)
with the operating system, architecture, downloaded filename, and exact error.
Never include tokens, API keys, private project files, or `.env` contents.
