#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="CommandCodeAI/desktop"
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

has_developer_id_signature() {
	app_path="$1"
	codesign -dv --verbose=4 "$app_path" 2>&1 |
		grep -q '^Authority=Developer ID Application:'
}

is_valid_version() {
	version_to_validate="$1"
	printf '%s\n' "$version_to_validate" |
		grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$'
}

validate_version() {
	version_to_validate="$1"
	is_valid_version "$version_to_validate" ||
		fail "The release returned an invalid version: $version_to_validate"
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

replace_macos_app() {
	staged_app="$1"
	destination="/Applications/Command Code.app"
	backup="/Applications/.Command Code.previous.$$"

	if [ -w /Applications ]; then
		if [ -e "$destination" ]; then
			mv "$destination" "$backup"
		fi
		if ! ditto "$staged_app" "$destination"; then
			rm -rf "$destination"
			if [ -e "$backup" ]; then
				mv "$backup" "$destination"
			fi
			fail "Could not copy Command Code into /Applications."
		fi
		rm -rf "$backup"
		return
	fi

	printf 'Administrator permission is required to install in /Applications.\n'
	if [ -e "$destination" ]; then
		sudo mv "$destination" "$backup"
	fi
	if ! sudo ditto "$staged_app" "$destination"; then
		sudo rm -rf "$destination"
		if sudo test -e "$backup"; then
			sudo mv "$backup" "$destination"
		fi
		fail "Could not copy Command Code into /Applications."
	fi
	sudo rm -rf "$backup"
}

mount_macos_archive() {
	archive_path="$1"

	mount_output="$(hdiutil attach -nobrowse -readonly "$archive_path")"
	MOUNT_POINT="$(
		printf '%s\n' "$mount_output" |
			sed -n 's#^.*\(/Volumes/.*\)$#\1#p' |
			tail -1
	)"
	[ -n "$MOUNT_POINT" ] || fail "Could not mount the downloaded DMG."

	APP_SOURCE="$(find "$MOUNT_POINT" -maxdepth 1 -type d -name '*.app' -print -quit)"
	if [ -z "$APP_SOURCE" ]; then
		fail "The DMG does not contain an application."
	fi
}

verify_macos_archive() {
	archive_path="$1"
	hdiutil verify "$archive_path" >/dev/null
	mount_macos_archive "$archive_path"
	[ -s "$APP_SOURCE/Contents/Resources/app/node_modules/@commandcode/harness/dist/index.js" ] ||
		fail "The macOS package is missing the compiled harness."
	[ -s "$APP_SOURCE/Contents/Resources/app/node_modules/command-code/dist/cli.mjs" ] ||
		fail "The macOS package is missing the compiled engine."
	hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
	MOUNT_POINT=""
}

install_macos() {
	archive_path="$1"
	mount_macos_archive "$archive_path"

	staged_app="$TEMPORARY_DIRECTORY/Command Code.app"
	ditto "$APP_SOURCE" "$staged_app"
	hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
	MOUNT_POINT=""

	# Releases are signed with a Developer ID and notarized. Anything that
	# fails these checks is a damaged or tampered download - never patch
	# around it on the user's machine.
	has_developer_id_signature "$staged_app" ||
		fail "The download is not signed with the Command Code Developer ID. Installation stopped without changing the existing app."
	spctl --assess --type execute "$staged_app" >/dev/null 2>&1 ||
		fail "The release failed Gatekeeper assessment. The download may be damaged. Installation stopped without changing the existing app."

	if pgrep -x "Command Code" >/dev/null 2>&1; then
		fail "Quit Command Code, then run the installer again."
	fi

	replace_macos_app "$staged_app"
	destination="/Applications/Command Code.app"
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
		require_command codesign
		require_command ditto
		require_command hdiutil
		require_command open
		require_command pgrep
		require_command spctl
		platform="macOS"
		artifact_architecture="arm64"
		artifact_extension="dmg"
		;;
	Linux:x86_64 | Linux:amd64)
		platform="Linux"
		artifact_architecture="amd64"
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
version=""
if [ -n "${COMMANDCODE_VERSION:-}" ]; then
	version="${COMMANDCODE_VERSION#v}"
	validate_version "$version"
	curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"$API_ROOT/releases/tags/v$version" \
		-o "$release_file"
else
	curl --fail --silent --show-error --location \
		-H "Accept: application/vnd.github+json" \
		"$API_ROOT/releases?per_page=20" \
		-o "$release_file"
fi

release_versions="$version"
if [ -z "${COMMANDCODE_VERSION:-}" ]; then
	release_versions="$(
		awk -F'"' '/"tag_name":/ {
			sub(/^v/, "", $4)
			print $4
		}' "$release_file"
	)"
fi
[ -n "$release_versions" ] || fail "Could not determine the latest release."

version=""
artifact_name=""
asset_metadata=""
while IFS= read -r candidate_version; do
	[ -n "$candidate_version" ] || continue
	is_valid_version "$candidate_version" || continue
	candidate_artifact="CommandCode-$candidate_version-$artifact_architecture.$artifact_extension"
	candidate_metadata="$(read_asset_metadata "$candidate_artifact" "$release_file")"
	if [ -n "$candidate_metadata" ]; then
		version="$candidate_version"
		artifact_name="$candidate_artifact"
		asset_metadata="$candidate_metadata"
		break
	fi
done <<EOF
$release_versions
EOF

[ -n "$artifact_name" ] ||
	fail "No verified $platform package was found in the 20 newest releases."
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

if [ "${COMMANDCODE_INSTALL_VERIFY_ONLY:-0}" = "1" ]; then
	if [ "$operating_system" = "Darwin" ]; then
		verify_macos_archive "$archive_path"
	fi
	printf 'Download verification completed without installing.\n'
	exit 0
fi

case "$operating_system" in
	Darwin) install_macos "$archive_path" ;;
	Linux) install_linux "$archive_path" ;;
esac

printf 'Command Code %s installed successfully.\n' "$version"
