$ErrorActionPreference = "Stop"

$Repository = "CommandCodeAI/gui"
$ApiRoot = "https://api.github.com/repos/$Repository"
$Headers = @{
	Accept = "application/vnd.github+json"
	"User-Agent" = "Command-Code-Installer"
}

function Stop-Install {
	param([string]$Message)
	throw "Command Code installer: $Message"
}

$IsVerificationMode =
	$env:COMMANDCODE_INSTALL_DRY_RUN -eq "1" -or
	$env:COMMANDCODE_INSTALL_VERIFY_ONLY -eq "1"
if (
	[System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT -and
	-not $IsVerificationMode
) {
	Stop-Install "install.ps1 must be run on Windows."
}

$Architecture = $env:PROCESSOR_ARCHITEW6432
if (-not $Architecture) {
	$Architecture = $env:PROCESSOR_ARCHITECTURE
}
if ($Architecture -ne "AMD64") {
	Stop-Install "The current Windows preview supports x64 only."
}

if ($env:COMMANDCODE_VERSION) {
	$Version = $env:COMMANDCODE_VERSION.TrimStart("v")
	if ($Version -notmatch "^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$") {
		Stop-Install "COMMANDCODE_VERSION is not a valid release version."
	}
	$Releases = Invoke-RestMethod `
		-Uri "$ApiRoot/releases/tags/v$Version" `
		-Headers $Headers `
		-UseBasicParsing
}
else {
	$Releases = Invoke-RestMethod `
		-Uri "$ApiRoot/releases?per_page=20" `
		-Headers $Headers `
		-UseBasicParsing
}

$Release = $null
$Asset = $null
$ArtifactName = $null
foreach ($CandidateRelease in $Releases) {
	$CandidateVersion = $CandidateRelease.tag_name.TrimStart("v")
	if ($CandidateVersion -notmatch "^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$") {
		continue
	}
	$CandidateArtifactName = "CommandCode-$CandidateVersion-x64-setup.exe"
	$CandidateAsset = $CandidateRelease.assets |
		Where-Object { $_.name -eq $CandidateArtifactName } |
		Select-Object -First 1
	if ($CandidateAsset) {
		$Release = $CandidateRelease
		$Version = $CandidateVersion
		$Asset = $CandidateAsset
		$ArtifactName = $CandidateArtifactName
		break
	}
}

if (-not $Release -or -not $Asset -or -not $ArtifactName) {
	Stop-Install "No verified Windows x64 package was found in the 20 newest releases."
}
if (-not $Asset.digest -or -not $Asset.digest.StartsWith("sha256:")) {
	Stop-Install "$ArtifactName does not have a published SHA-256 digest."
}

if ($env:COMMANDCODE_INSTALL_DRY_RUN -eq "1") {
	Write-Host "Resolved Command Code $Version for Windows: $ArtifactName"
	exit 0
}

$TemporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "command-code-install-$([guid]::NewGuid())"
$InstallerPath = Join-Path $TemporaryDirectory $ArtifactName
New-Item -ItemType Directory -Path $TemporaryDirectory | Out-Null

try {
	Write-Host "Downloading Command Code $Version for Windows..."
	Invoke-WebRequest `
		-Uri $Asset.browser_download_url `
		-OutFile $InstallerPath `
		-UseBasicParsing

	$ExpectedDigest = $Asset.digest.Substring("sha256:".Length).ToLowerInvariant()
	$ActualDigest = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash.ToLowerInvariant()
	if ($ActualDigest -ne $ExpectedDigest) {
		Stop-Install "Downloaded file failed SHA-256 verification."
	}
	Write-Host "Verified SHA-256: $ExpectedDigest"

	if ($env:COMMANDCODE_INSTALL_VERIFY_ONLY -eq "1") {
		Write-Host "Download verification completed without installing."
		return
	}

	$Signature = Get-AuthenticodeSignature -FilePath $InstallerPath
	if ($Signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
		Write-Warning "This preview is not yet Authenticode signed."
		$Confirmation = Read-Host "Continue with the official verified installer? [y/N]"
		if ($Confirmation -notmatch "^(y|yes)$") {
			Stop-Install "Installation cancelled."
		}
		Unblock-File -Path $InstallerPath
	}

	$Process = Start-Process -FilePath $InstallerPath -PassThru -Wait
	if ($Process.ExitCode -ne 0) {
		Stop-Install "The Windows installer exited with code $($Process.ExitCode)."
	}

	$InstalledApplication = $null
	$InstallCandidates = @(
		(Join-Path $env:LOCALAPPDATA "Programs\Command Code\Command Code.exe")
		(Join-Path $env:LOCALAPPDATA "Programs\command-code\Command Code.exe")
		(Join-Path $env:ProgramFiles "Command Code\Command Code.exe")
	)
	foreach ($CandidatePath in $InstallCandidates) {
		if (Test-Path $CandidatePath) {
			$InstalledApplication = $CandidatePath
			break
		}
	}

	if (-not $InstalledApplication) {
		$ShortcutDirectory = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
		$Shortcut = Get-ChildItem `
			-Path $ShortcutDirectory `
			-Filter "Command Code*.lnk" `
			-Recurse `
			-ErrorAction SilentlyContinue |
			Select-Object -First 1
		if ($Shortcut) {
			$Shell = New-Object -ComObject WScript.Shell
			$ShortcutTarget = $Shell.CreateShortcut($Shortcut.FullName).TargetPath
			if ($ShortcutTarget -and (Test-Path $ShortcutTarget)) {
				$InstalledApplication = $ShortcutTarget
			}
		}
	}

	if (-not $InstalledApplication) {
		Stop-Install "Installation finished, but Command Code.exe was not found."
	}

	Start-Process -FilePath $InstalledApplication
	Write-Host "Command Code $Version installed successfully."
}
finally {
	Remove-Item -Path $TemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
