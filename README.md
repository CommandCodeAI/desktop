<div align="center">

# Command Code GUI

The visual workspace for Command Code.

[Product page](https://commandcode.ai/gui) · [Releases](https://github.com/CommandCodeAI/gui/releases) · [Report a bug](https://github.com/CommandCodeAI/gui/issues/new/choose) · [Discord](https://commandcode.ai/discord)

</div>

## Install

The installer detects your operating system and architecture, downloads the
newest official release, verifies its SHA-256 digest, and installs the app.

macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/CommandCodeAI/gui/main/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/CommandCodeAI/gui/main/install.ps1 | iex
```

[Read the macOS/Linux installer](install.sh) ·
[Read the Windows installer](install.ps1) ·
[Installation details](INSTALL.md)

> [!IMPORTANT]
> Preview builds are not yet signed by Apple or Microsoft. The installers
> verify GitHub's published SHA-256 digest and ask before applying any temporary
> unsigned-build workaround. They never disable operating-system security
> globally. Signed and notarized builds will use the normal trust flow.

## Direct downloads

| Platform | Current build |
| --- | --- |
| macOS | [Apple silicon DMG](https://github.com/CommandCodeAI/gui/releases) |
| Linux | [x64 DEB](https://github.com/CommandCodeAI/gui/releases) |
| Windows | [x64 installer](https://github.com/CommandCodeAI/gui/releases) |

## What is Command Code GUI?

Command Code GUI brings the Command Code agent into a focused desktop
workspace. Manage projects and chats, review plans, inspect file changes, work
with Git, and use the integrated terminal without leaving the application.

- Project and session management
- Streaming agent conversations and task progress
- Plan review and iterative feedback
- File browser, source preview, and line-level diffs
- Git changes, discard, commit, and push workflows
- Integrated project terminal
- Configurable models, permissions, themes, and shortcuts

## Feedback

- [Open a bug report](https://github.com/CommandCodeAI/gui/issues/new/choose)
- [Join the Discord community](https://commandcode.ai/discord)
- Read [SUPPORT.md](SUPPORT.md) before sharing logs or screenshots

Report vulnerabilities privately by following [SECURITY.md](SECURITY.md).

## Repository scope

This is the public download, installer, documentation, and issue-tracking
repository for Command Code GUI. Application development happens in a private
repository.

© Command Code
