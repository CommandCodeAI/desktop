# Install Command Code GUI

Download version 0.1.0 from the official
[GitHub Releases page](https://github.com/CommandCodeAI/gui/releases).

> [!WARNING]
> Version 0.1.0 is an unsigned public preview. Only install files downloaded
> from `github.com/CommandCodeAI/gui`, and verify the published SHA-256
> checksum before bypassing an operating-system warning.

## macOS

The current macOS preview supports Apple silicon.

1. Download `CommandCode-0.1.0-arm64.dmg` and `SHA256SUMS`.
2. In Terminal, verify the download:

   ```bash
   cd ~/Downloads
   grep 'CommandCode-0.1.0-arm64.dmg' SHA256SUMS | shasum -a 256 -c -
   ```

3. Open the DMG and drag **Command Code** into **Applications**.
4. In Applications, Control-click **Command Code**, choose **Open**, and then
   choose **Open** again.

If macOS still reports that the verified app is damaged:

```bash
xattr -dr com.apple.quarantine "/Applications/Command Code.app"
open "/Applications/Command Code.app"
```

Run that command only after the checksum succeeds. Do not disable Gatekeeper
globally.

### Remove the macOS preview

Quit Command Code, then move `/Applications/Command Code.app` to the Trash.

## Linux

### Debian or Ubuntu

1. Download `CommandCode-0.1.0-linux-x64.deb` and `SHA256SUMS`.
2. Verify and install:

   ```bash
   cd ~/Downloads
   grep 'CommandCode-0.1.0-linux-x64.deb' SHA256SUMS | sha256sum -c -
   sudo apt install ./CommandCode-0.1.0-linux-x64.deb
   ```

### AppImage

If the release includes an AppImage:

```bash
cd ~/Downloads
grep 'CommandCode-0.1.0-linux-x64.AppImage' SHA256SUMS | sha256sum -c -
chmod +x CommandCode-0.1.0-linux-x64.AppImage
./CommandCode-0.1.0-linux-x64.AppImage
```

## Windows

Windows is not included in the 0.1.0 public preview. Do not download Windows
installers shared by unofficial accounts.

## Updating

Automatic updates are disabled for unsigned previews. To update:

1. Open the [Releases page](https://github.com/CommandCodeAI/gui/releases).
2. Download and verify the newest build.
3. Install it over the existing version.

Signed builds will use the normal operating-system trust flow and support
automatic updates.

## Getting help

If installation fails, [open a bug report](https://github.com/CommandCodeAI/gui/issues/new/choose)
with your operating system, device architecture, downloaded filename, and the
exact error. Never include tokens, API keys, private project files, or `.env`
contents.
