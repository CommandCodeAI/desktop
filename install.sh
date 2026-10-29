#!/usr/bin/env bash

set -euo pipefail

REPOSITORY="CommandCodeAI/desktop"
API_ROOT="https://api.github.com/repos/$REPOSITORY"
TEMPORARY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/command-code-install.XXXXXX")"
MOUNT_POINT=""
linux_flavor=""
linux_installer=""

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
	# Capture first: `grep -q` exits on the first match, codesign then dies
	# of SIGPIPE, and pipefail turns a valid signature into a failure.
	signature="$(codesign -dv --verbose=4 "$app_path" 2>&1)" || return 1
	printf '%s\n' "$signature" | grep -q '^Authority=Developer ID Application:'
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
		/"url": "https:\/\/api.github.com\/repos\/[^\/]+\/[^\/]+\/releases\/assets\// {
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

detect_linux_package_manager() {
	if command -v apt-get >/dev/null 2>&1; then
		linux_flavor="apt"
		linux_installer="apt-get"
	elif command -v dnf >/dev/null 2>&1; then
		linux_flavor="rpm"
		linux_installer="dnf"
	elif command -v zypper >/dev/null 2>&1; then
		linux_flavor="rpm"
		linux_installer="zypper"
	elif command -v yum >/dev/null 2>&1; then
		linux_flavor="rpm"
		linux_installer="yum"
	fi
}

# On rpm-based systems prefer a native .rpm when the release publishes one;
# otherwise fall back to the .deb, which this installer repacks locally.
artifact_candidates() {
	version_for_artifacts="$1"

	if [ "${linux_flavor:-}" = "rpm" ]; then
		printf '%s\n' \
			"CommandCode-$version_for_artifacts-x86_64.rpm" \
			"CommandCode-$version_for_artifacts-$artifact_architecture.$artifact_extension"
	else
		printf '%s\n' \
			"CommandCode-$version_for_artifacts-$artifact_architecture.$artifact_extension"
	fi
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

extract_deb_payload() {
	deb_path="$1"
	payload_root="$2"
	payload_archive=""

	if command -v ar >/dev/null 2>&1; then
		extract_directory="$TEMPORARY_DIRECTORY/deb"
		mkdir -p "$extract_directory"
		(cd "$extract_directory" && ar x "$deb_path") ||
			fail "Could not unpack the downloaded .deb package."
		for archive_member in data.tar.xz data.tar.gz; do
			if [ -f "$extract_directory/$archive_member" ]; then
				payload_archive="$extract_directory/$archive_member"
				break
			fi
		done
	elif command -v bsdtar >/dev/null 2>&1; then
		for archive_member in data.tar.xz data.tar.gz; do
			if bsdtar -x -f "$deb_path" -C "$TEMPORARY_DIRECTORY" "$archive_member" >/dev/null 2>&1; then
				payload_archive="$TEMPORARY_DIRECTORY/$archive_member"
				break
			fi
		done
	else
		fail "ar (binutils) or bsdtar is required to unpack the package on this system."
	fi

	[ -n "$payload_archive" ] ||
		fail "Could not find the payload inside the downloaded .deb package."
	mkdir -p "$payload_root"
	tar -xf "$payload_archive" -C "$payload_root" ||
		fail "Could not extract the payload from the downloaded .deb package."

	[ -x "$payload_root/opt/Command Code/command-code" ] ||
		fail "The package payload is missing the Command Code executable."
	[ -s "$payload_root/usr/share/applications/command-code.desktop" ] ||
		fail "The package payload is missing the desktop entry."
	[ -s "$payload_root/opt/Command Code/resources/app/node_modules/command-code/dist/cli.mjs" ] ||
		fail "The package payload is missing the compiled engine."
}

install_rpm_package() {
	rpm_path="$1"

	printf 'Administrator permission is required to install the package.\n'
	case "$linux_installer" in
		dnf | yum)
			if ! sudo "$linux_installer" install -y "$rpm_path" >/dev/null; then
				sudo "$linux_installer" reinstall -y "$rpm_path" ||
					fail "Could not install the RPM package."
			fi
			;;
		zypper)
			sudo zypper --non-interactive install "$rpm_path" ||
				fail "Could not install the RPM package."
			;;
		*)
			fail "Unsupported package manager: $linux_installer."
			;;
	esac
}

install_linux_rpm_from_deb() {
	deb_path="$1"
	payload_root="$TEMPORARY_DIRECTORY/payload"

	printf 'This release has no native .rpm; repacking the verified .deb.\n'
	extract_deb_payload "$deb_path" "$payload_root"

	if command -v rpmbuild >/dev/null 2>&1; then
		install_linux_rpm_via_rpmbuild "$payload_root"
	else
		install_linux_rpm_direct "$payload_root"
	fi
}

install_linux_rpm_via_rpmbuild() {
	payload_root="$1"
	rpm_version="${version//-/.}"
	build_root="$TEMPORARY_DIRECTORY/rpmbuild"
	spec_path="$build_root/SPECS/command-code.spec"
	doc_install=""
	doc_files=""

	mkdir -p "$build_root/BUILD" "$build_root/BUILDROOT" "$build_root/RPMS" \
		"$build_root/SOURCES" "$build_root/SPECS" "$build_root/SRPMS"
	if [ -d "$payload_root/usr/share/doc/command-code" ]; then
		doc_install="mkdir -p %{buildroot}%{_docdir}/%{name}
cp -a '$payload_root/usr/share/doc/command-code/.' %{buildroot}%{_docdir}/%{name}/"
		doc_files="%{_docdir}/%{name}/*"
	fi

	cat >"$spec_path" <<SPEC
Name: command-code
Version: $rpm_version
Release: 1%{?dist}
Summary: Command Code desktop app
License: Apache-2.0
URL: https://github.com/CommandCodeAI/desktop

# The payload bundles optional native modules for other platforms (arm64,
# musl, Windows, macOS); the automatic dependency scan would emit requires
# that do not exist on this system. Runtime dependencies are explicit below.
AutoReq: no
%define debug_package %{nil}
%define __os_install_post %{nil}

Requires: gtk3
Requires: libnotify
Requires: nss
Requires: nspr
Requires: libXScrnSaver
Requires: libXtst
Requires: xdg-utils
Requires: at-spi2-core
Requires: libuuid
Requires: libsecret
Requires: alsa-lib

%description
Command Code desktop app, installed from the official verified release.

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt
cp -a '$payload_root/opt/.' %{buildroot}/opt/
mkdir -p %{buildroot}%{_bindir}
ln -s '/opt/Command Code/command-code' %{buildroot}%{_bindir}/command-code
mkdir -p %{buildroot}%{_datadir}
cp -a '$payload_root/usr/share/applications' %{buildroot}%{_datadir}/
cp -a '$payload_root/usr/share/icons' %{buildroot}%{_datadir}/
$doc_install

%files
/opt/Command*
%{_bindir}/command-code
%{_datadir}/applications/command-code.desktop
%{_datadir}/icons/hicolor/*/apps/command-code.png
$doc_files

%post
chmod 4755 '/opt/Command Code/chrome-sandbox' >/dev/null 2>&1 || :
if [ -x /usr/bin/update-desktop-database ]; then
	/usr/bin/update-desktop-database /usr/share/applications >/dev/null 2>&1 || :
fi
if [ -x /usr/bin/gtk-update-icon-cache ]; then
	/usr/bin/gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || :
fi
if [ -x /usr/sbin/restorecon ]; then
	/usr/sbin/restorecon -R '/opt/Command Code' /usr/bin/command-code >/dev/null 2>&1 || :
fi

%postun
if [ -x /usr/bin/gtk-update-icon-cache ]; then
	/usr/bin/gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || :
fi
SPEC

	if ! rpmbuild -bb --define "_topdir $build_root" "$spec_path" \
		>"$TEMPORARY_DIRECTORY/rpmbuild.log" 2>&1; then
		build_error="$(tr '\n' ' ' <"$TEMPORARY_DIRECTORY/rpmbuild.log" | cut -c1-300)"
		fail "Could not build a local RPM from the verified download. $build_error"
	fi

	built_rpm="$(find "$build_root/RPMS" -type f -name '*.rpm' -print -quit)"
	[ -n "$built_rpm" ] ||
		fail "The local RPM build produced no package."

	install_rpm_package "$built_rpm"
}

install_linux_rpm_direct() {
	payload_root="$1"

	printf 'rpmbuild is not installed; installing the payload directly.\n'
	printf 'Administrator permission is required to install the package.\n'
	sudo cp -a "$payload_root/opt/." /opt/ ||
		fail "Could not copy Command Code into /opt."
	sudo mkdir -p /usr/share/applications /usr/share/icons
	sudo cp -a "$payload_root/usr/share/applications/command-code.desktop" /usr/share/applications/ ||
		fail "Could not install the desktop entry."
	sudo cp -a "$payload_root/usr/share/icons/." /usr/share/icons/ ||
		fail "Could not install the icons."
	if [ -d "$payload_root/usr/share/doc/command-code" ]; then
		sudo mkdir -p /usr/share/doc/command-code
		sudo cp -a "$payload_root/usr/share/doc/command-code/." /usr/share/doc/command-code/ || true
	fi
	sudo ln -sf '/opt/Command Code/command-code' /usr/bin/command-code ||
		fail "Could not create the command-code launcher."
	sudo chmod 4755 '/opt/Command Code/chrome-sandbox'
	sudo update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
	sudo gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
	sudo restorecon -R '/opt/Command Code' /usr/bin/command-code >/dev/null 2>&1 || true

	printf 'To remove this direct installation, run:\n'
	printf "  sudo rm -rf '/opt/Command Code' /usr/bin/command-code /usr/share/doc/command-code\n"
	printf '  sudo rm -f /usr/share/applications/command-code.desktop\n'
	printf '  sudo rm -f /usr/share/icons/hicolor/*/apps/command-code.png\n'
}

install_linux() {
	archive_path="$1"

	case "$linux_flavor" in
		apt)
			printf 'Administrator permission is required to install the package.\n'
			sudo apt-get install -y "$archive_path"
			;;
		rpm)
			case "$artifact_extension" in
				rpm) install_rpm_package "$archive_path" ;;
				deb) install_linux_rpm_from_deb "$archive_path" ;;
			esac
			;;
		*)
			fail "This preview supports Debian and Ubuntu through a .deb package and Fedora, RHEL, and openSUSE through the installer."
			;;
	esac
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
		artifact_architecture="macOS-Apple-Silicon-arm64"
		artifact_extension="dmg"
		;;
	Darwin:x86_64)
		require_command codesign
		require_command ditto
		require_command hdiutil
		require_command open
		require_command pgrep
		require_command spctl
		platform="macOS"
		artifact_architecture="macOS-Intel-x64"
		artifact_extension="dmg"
		;;
	Linux:x86_64 | Linux:amd64)
		platform="Linux"
		artifact_architecture="amd64"
		artifact_extension="deb"
		detect_linux_package_manager
		[ -n "$linux_flavor" ] ||
			fail "No supported package manager found. This preview supports Debian and Ubuntu through a .deb package and Fedora, RHEL, and openSUSE through the installer."
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
	for candidate_artifact in $(artifact_candidates "$candidate_version"); do
		candidate_metadata="$(read_asset_metadata "$candidate_artifact" "$release_file")"
		if [ -n "$candidate_metadata" ]; then
			version="$candidate_version"
			artifact_name="$candidate_artifact"
			asset_metadata="$candidate_metadata"
			break 2
		fi
	done
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
