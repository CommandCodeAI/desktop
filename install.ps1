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

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
	Stop-Install "install.ps1 must be run on Windows."
}

$Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
if ($Architecture -ne [System.Runtime.InteropServices.Architecture]::X64) {
	Stop-Install "The current Windows preview supports x64 only."
}

if ($env:COMMANDCODE_VERSION) {
	$Version = $env:COMMANDCODE_VERSION.TrimStart("v")
	$Release = Invoke-RestMethod `
		-Uri "$ApiRoot/releases/tags/v$Version" `
		-Headers $Headers
}
else {
	$Release = Invoke-RestMethod `
		-Uri "$ApiRoot/releases?per_page=1" `
		-Headers $Headers |
		Select-Object -First 1
	$Version = $Release.tag_name.TrimStart("v")
}

if (-not $Version) {
	Stop-Install "Could not determine the latest release."
}

$ArtifactName = "CommandCode-$Version-x64-setup.exe"
$Asset = $Release.assets | Where-Object { $_.name -eq $ArtifactName } | Select-Object -First 1
if (-not $Asset) {
	Stop-Install "$ArtifactName is not available in v$Version."
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
	Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $InstallerPath

	$ExpectedDigest = $Asset.digest.Substring("sha256:".Length).ToLowerInvariant()
	$ActualDigest = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash.ToLowerInvariant()
	if ($ActualDigest -ne $ExpectedDigest) {
		Stop-Install "Downloaded file failed SHA-256 verification."
	}
	Write-Host "Verified SHA-256: $ExpectedDigest"

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

	$InstalledApplication = Join-Path $env:LOCALAPPDATA "Programs\Command Code\Command Code.exe"
	if (-not (Test-Path $InstalledApplication)) {
		Stop-Install "Installation finished, but Command Code.exe was not found."
	}

	Start-Process -FilePath $InstalledApplication
	Write-Host "Command Code $Version installed successfully."
}
finally {
	Remove-Item -Path $TemporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
