$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$name = '31896935-DD54-4362-ACDD-6DA496624671'
$package = Get-AppxPackage -Name $name
if (-not $package -or [version]$package.Version -lt [version]'5.9.0.53') {
  $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
  $hashes = @{
    x64 = '8cc6b10542374b4bcdfc5da0b613fd6b97a4f01085cbbadeaa6fc67f5f534ef9'
    ARM64 = 'c2e7744d0a582ac005232dec0fb74cc13fbc971a11e02b835d0f2b982b03d0d7'
  }
  if (-not $hashes.ContainsKey($arch)) { throw "Unsupported architecture: $arch" }
  $assetArch = if ($arch -eq 'X64') { 'x64' } else { 'ARM64' }
  $url = "https://github.com/ikas-mc/ContextMenuForWindows11/releases/download/5.9.0.2/ContextMenuCustom-CMC_GITHUB_RELEASE-$assetArch.zip"
  $work = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([guid]::NewGuid()))
  try {
    $zip = Join-Path $work.FullName 'release.zip'
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
    if ((Get-FileHash $zip).Hash -ne $hashes[$arch]) { throw 'Unexpected GitHub release hash.' }
    Expand-Archive -LiteralPath $zip -DestinationPath $work.FullName
    $bundle = Get-Item "$work\ContextMenuCustomGithubPackage_*_Test\*.msixbundle"
    $cert = Get-Item "$($bundle.DirectoryName)\*.cer"
    Import-Certificate -FilePath $cert.FullName -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null
    try {
      Add-AppxPackage -Path $bundle.FullName
    } catch {
      if ($_ -notmatch '0x80073CF3') { throw }
      $deps = Get-Item "$($bundle.DirectoryName)\Dependencies\$assetArch\*.appx"
      Add-AppxPackage -Path $bundle.FullName -DependencyPath $deps.FullName
    }
    $package = Get-AppxPackage -Name $name
    if (-not $package) { throw 'GitHub edition of Custom Context Menu was not registered.' }
  } finally {
    Remove-Item -LiteralPath $work.FullName -Recurse -Force
  }
}

$folder = Join-Path $env:LOCALAPPDATA "Packages\$($package.PackageFamilyName)\LocalState\custom_commands"
New-Item -ItemType Directory -Force -Path $folder | Out-Null
Copy-Item -LiteralPath "$PSScriptRoot\nvim-menu.json" -Destination $folder -Force
