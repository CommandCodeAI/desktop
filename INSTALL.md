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
3. Select the matching `.dmg`, `.deb`, or `.exe` (or a native `.rpm` when
   one is published).
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

## RPM-based Linux (Fedora, RHEL, openSUSE)

Releases currently publish a Linux `.deb`. On rpm-based distributions the
installer:

1. Downloads the `.deb` and verifies its SHA-256 digest first, exactly as on
   Debian and Ubuntu.
2. Prefers a native `.rpm` automatically as soon as a release publishes one.
3. Unpacks the verified `.deb` and repacks the payload into a local RPM with
   `rpmbuild`, then installs it with `dnf` or `zypper` so the package is
   tracked and removable through the package manager.
4. Falls back to installing the payload directly (with the same file layout,
   launcher, and desktop entry) when `rpmbuild` is not available; that
   variant prints the exact paths to remove when uninstalling.

Uninstall a local-RPM installation with `sudo dnf remove command-code` (or
`sudo zypper remove command-code`).

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
