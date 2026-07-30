#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="CommandCodeAI/gui"
API_ROOT="https://api.github.com/repos/$REPOSITORY"
TEMPORARY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/command-code-install.XXXXXX")"
MOUNT_POINT=""

cleanup() {
	if [ -n "$MOUNT_POINT" ]; then
		hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
	fi
	rm -rf "$TEMPORARY_DIRECTORY"
}

trap cleanup EXIT

fail() {
	printf 'Command Code installer: %s\n' "$*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 ||
		fail "$1 is required but is not installed."
}

confirm_unsigned_macos() {
	printf '%s\n' \
		'This preview is not yet signed by Apple.' \
		'Continuing will remove quarantine from Command Code only and apply' \
		'a local ad-hoc signature. It will not disable Gatekeeper.'
	printf 'Continue? [y/N] '
	read -r confirmation </dev/tty || confirmation=""
	case "$confirmation" in
		y | Y | yes | YES) ;;
		*) fail "Installation cancelled." ;;
	esac
}

read_asset_metadata() {
	artifact_name="$1"
	release_file="$2"

	awk -v wanted="$artifact_name" '
		/"url": "https:\/\/api.github.com\/repos\/CommandCodeAI\/gui\/releases\/assets\// {
			in_asset = 1
			asset_name = ""
			digest = ""
		}
		in_asset && /"name":/ {
			value = $0
			sub(/^.*"name": "/, "", value)
			sub(/".*$/, "", value)
			asset_name = value
		}
		in_asset && /"digest": "sha256:/ {
			value = $0
			sub(/^.*"digest": "/, "", value)
			sub(/".*$/, "", value)
			digest = value
		}
		in_asset && /"browser_download_url":/ {
			value = $0
			sub(/^.*"browser_download_url": "/, "", value)
			sub(/".*$/, "", value)
			if (asset_name == wanted) {
				print digest
				print value
				exit
			}
			in_asset = 0
		}
	' "$release_file"
}

verify_sha256() {
	file_path="$1"
	expected_digest="$2"

	if command -v sha256sum >/dev/null 2>&1; then
		actual_digest="$(sha256sum "$file_path" | awk '{print $1}')"
	elif command -v shasum >/dev/null 2>&1; then
		actual_digest="$(shasum -a 256 "$file_path" | awk '{print $1}')"
	else
		fail "sha256sum or shasum is required to verify the download."
	fi

	[ "$actual_digest" = "$expected_digest" ] ||
		fail "Downloaded file failed SHA-256 verification."
}

install_macos() {
	archive_path="$1"

	mount_output="$(hdiutil attach -nobrowse -readonly "$archive_path")"
	MOUNT_POINT="$(
		printf '%s\n' "$mount_output" |
			sed -n 's#^.*\(/Volumes/.*\)$#\1#p' |
			tail -1
	)"
	[ -n "$MOUNT_POINT" ] || fail "Could not mount the downloaded DMG."

	app_source="$(find "$MOUNT_POINT" -maxdepth 1 -type d -name '*.app' -print -quit)"
	if [ -z "$app_source" ]; then
		fail "The DMG does not contain an application."
	fi

	destination="/Applications/Command Code.app"
	if [ -w /Applications ]; then
		rm -rf "$destination"
		ditto "$app_source" "$destination"
	else
		printf 'Administrator permission is required to install in /Applications.\n'
		sudo rm -rf "$destination"
		sudo ditto "$app_source" "$destination"
	fi
	hdiutil detach "$MOUNT_POINT" >/dev/null
	MOUNT_POINT=""

	if ! spctl --assess --type execute "$destination" >/dev/null 2>&1; then
		confirm_unsigned_macos
		if [ -w "$destination" ]; then
			xattr -dr com.apple.quarantine "$destination"
			codesign --force --deep --sign - "$destination"
		else
			sudo xattr -dr com.apple.quarantine "$destination"
			sudo codesign --force --deep --sign - "$destination"
		fi
	fi

	open "$destination"
}

install_linux() {
	archive_path="$1"

	command -v apt-get >/dev/null 2>&1 ||
		fail "This preview currently supports Debian and Ubuntu through a .deb package."
	printf 'Administrator permission is required to install the package.\n'
	sudo apt-get install -y "$archive_path"
}

require_command curl
require_command uname

operating_system="$(uname -s)"
machine_architecture="$(uname -m)"

case "$operating_system:$machine_architecture" in
	Darwin:arm64 | Darwin:aarch64)
		platform="macOS"
		artifact_architecture="arm64"
		artifact_extension="dmg"
		;;
	Linux:x86_64 | Linux:amd64)
		platform="Linux"
		artifact_architecture="x64"
		artifact_extension="deb"
		;;
	Darwin:*)
		fail "The current macOS preview supports Apple silicon only."
		;;
	Linux:*)
		fail "The current Linux preview supports x64 only."
		;;
	*)
		fail "Use install.ps1 to install Command Code on Windows."
		;;
esac

release_file="$TEMPORARY_DIRECTORY/release.json"
if [ -n "${COMMANDCODE_VERSION:-}" ]; then
	version="${COMMANDCODE_VERSION#v}"
	curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"$API_ROOT/releases/tags/v$version" \
		-o "$release_file"
else
	curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"$API_ROOT/releases?per_page=1" \
		-o "$release_file"
	version="$(
		awk -F'"' '/"tag_name":/ {
			sub(/^v/, "", $4)
			print $4
			exit
		}' "$release_file"
	)"
fi
[ -n "$version" ] || fail "Could not determine the latest release."

artifact_name="CommandCode-$version-$artifact_architecture.$artifact_extension"
asset_metadata="$(read_asset_metadata "$artifact_name" "$release_file")"
asset_digest="$(printf '%s\n' "$asset_metadata" | sed -n '1p')"
asset_url="$(printf '%s\n' "$asset_metadata" | sed -n '2p')"

case "$asset_digest" in
	sha256:*) expected_digest="${asset_digest#sha256:}" ;;
	*) fail "$artifact_name is unavailable or does not have a published SHA-256 digest." ;;
esac
[ -n "$asset_url" ] || fail "$artifact_name is not available in v$version."

if [ "${COMMANDCODE_INSTALL_DRY_RUN:-0}" = "1" ]; then
	printf 'Resolved Command Code %s for %s: %s\n' \
		"$version" \
		"$platform" \
		"$artifact_name"
	exit 0
fi

archive_path="$TEMPORARY_DIRECTORY/$artifact_name"
printf 'Downloading Command Code %s for %s...\n' "$version" "$platform"
curl --fail --show-error --location "$asset_url" -o "$archive_path"
verify_sha256 "$archive_path" "$expected_digest"
printf 'Verified SHA-256: %s\n' "$expected_digest"

case "$operating_system" in
	Darwin) install_macos "$archive_path" ;;
	Linux) install_linux "$archive_path" ;;
esac

printf 'Command Code %s installed successfully.\n' "$version"
