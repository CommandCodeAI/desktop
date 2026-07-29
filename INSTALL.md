# Install Command Code GUI

Download version 0.1.0 directly from the official repository:

[Download Command Code 0.1.0 for Apple silicon](https://github.com/CommandCodeAI/gui/releases/download/v0.1.0/CommandCode-0.1.0-arm64.dmg)

> [!WARNING]
> Version 0.1.0 is an unsigned public preview. Only install files downloaded
> from `github.com/CommandCodeAI/gui`, and verify the SHA-256 digest below
> before bypassing an operating-system warning.

## macOS

The current macOS preview supports Apple silicon.

1. Download `CommandCode-0.1.0-arm64.dmg` using the link above.
2. In Terminal, verify the download:

   ```bash
   cd ~/Downloads
   echo '464a7756bcf80e7961954e44a14b54c08e23adb8f7da84a41c4234717459f39c  CommandCode-0.1.0-arm64.dmg' | shasum -a 256 -c -
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

Linux is not included in the 0.1.0 public preview. The download and verified
installation instructions will be added when the Linux package passes its
release gate.

## Windows

Windows is not included in the 0.1.0 public preview. Do not download Windows
installers shared by unofficial accounts.

## Updating

Automatic updates are disabled for unsigned previews. To update:

1. Open the [product page](https://commandcode.ai/gui).
2. Download and verify the newest DMG.
3. Install it over the existing version.

Signed builds will use the normal operating-system trust flow and support
automatic updates.

## Getting help

If installation fails, [open a bug report](https://github.com/CommandCodeAI/gui/issues/new/choose)
with your operating system, device architecture, downloaded filename, and the
exact error. Never include tokens, API keys, private project files, or `.env`
contents.
