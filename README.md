<div align="center">

# Command Code Desktop App

The visual workspace for Command Code.

[Product page](https://commandcode.ai/) · [Releases](https://github.com/CommandCodeAI/desktop/releases) · [Report a bug](https://github.com/CommandCodeAI/desktop/issues/new/choose) · [Discord](https://commandcode.ai/discord)

</div>

## Install or update

Copy the command for your operating system and paste it into the terminal.
Running the same command again installs the newest available version.

### macOS and Linux

One command for both. The script detects the system - Apple silicon macOS or
Ubuntu/Debian x64 Linux - and installs the matching build:

```bash
curl -fsSL https://raw.githubusercontent.com/CommandCodeAI/desktop/main/install.sh | bash
```

### Windows

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/CommandCodeAI/desktop/main/install.ps1 | iex
```

The installer:

1. Detects the operating system and CPU architecture.
2. Selects the newest matching release.
3. Downloads only from `CommandCodeAI/desktop`.
4. Verifies GitHub's published SHA-256 digest.
5. Installs and opens Command Code.

It exits without installing when a matching verified release is unavailable.

> [!IMPORTANT]
> macOS releases are signed with an Apple Developer ID and notarized by Apple.
> The installer verifies the signature and Gatekeeper assessment and stops if
> either check fails - it never modifies a build or weakens a security
> control. Windows preview builds are not yet production-signed; the installer
> asks before opening one, and that prompt disappears when Windows signing
> lands.

[Read `install.sh`](install.sh) ·
[Read `install.ps1`](install.ps1) ·
[Installation details](INSTALL.md)

<details>
<summary>Install a specific version</summary>

macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/CommandCodeAI/desktop/main/install.sh | COMMANDCODE_VERSION=0.1.3 bash
```

Windows PowerShell:

```powershell
$env:COMMANDCODE_VERSION="0.1.3"; irm https://raw.githubusercontent.com/CommandCodeAI/desktop/main/install.ps1 | iex
```

</details>

## Direct downloads

Prefer the installer above because it selects and verifies the correct build
automatically. Manual packages are available on the
[releases page](https://github.com/CommandCodeAI/desktop/releases).

| Platform | Package | Architecture |
| --- | --- | --- |
| macOS | `.dmg` | Apple silicon |
| Linux | `.deb` | x64 |
| Windows | `.exe` | x64 |

## What you can do

- Organize projects and session history
- Stream agent conversations and task progress
- Review plans and send iterative feedback
- Browse files and inspect line-level diffs
- Review, discard, commit, and push Git changes
- Run commands in the integrated project terminal
- Choose models, permission modes, themes, and shortcuts

## Requirements

- A supported operating system and architecture from the table above
- Internet access to download the release from GitHub
- Administrator permission when the operating system requires it

Command Code CLI does not need to be installed separately.

## Help and feedback

- [Report an installation problem or GUI bug](https://github.com/CommandCodeAI/desktop/issues/new/choose)
- [Join the Discord community](https://commandcode.ai/discord)
- Read [SUPPORT.md](SUPPORT.md) before sharing logs or screenshots

Report security vulnerabilities privately by following
[SECURITY.md](SECURITY.md). Do not include tokens, private source files, or
`.env` contents in public reports.

## Repository scope

This is the public download, installer, documentation, and issue-tracking
repository for Command Code GUI. Application development happens in a private
repository.

© Command Code
