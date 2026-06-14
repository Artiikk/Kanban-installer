# Vibe CLI installer for Windows (GitHub releases, private-repo capable).
#
# Carries no secrets — host it PUBLICLY so `irm … | iex` resolves. Release
# archives stay in the PRIVATE repo; this script pulls them with a token via
# the releases API (the browser `releases/latest/download` path 404s for
# private repos).
#
# Auth: set $env:VIBE_TOKEN to a GitHub PAT with `repo` read access
#       (GITHUB_TOKEN / GH_TOKEN are also accepted).
# Overrides: $env:VIBE_REPO, $env:VIBE_INSTALL_DIR.
$ErrorActionPreference = "Stop"

$Repo = if ($env:VIBE_REPO) { $env:VIBE_REPO } else { "Artiikk/Kanban-installer" }
$Token = $env:VIBE_TOKEN
if (-not $Token) { $Token = $env:GITHUB_TOKEN }
if (-not $Token) { $Token = $env:GH_TOKEN }
if (-not $Token) { throw "install: set `$env:VIBE_TOKEN to a GitHub PAT with read access to $Repo" }

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
$suffix = "-windows-$arch.zip"
$legacy = "bcc_vibe_windows_$arch.zip"

$headers = @{ Authorization = "Bearer $Token"; Accept = "application/vnd.github+json" }
$release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repo/releases/latest"
$names = $release.assets | ForEach-Object { $_.name }

$asset = $names | Where-Object { $_ -like "bcc-vibe-cli-*$suffix" } | Select-Object -First 1
if (-not $asset) { $asset = $names | Where-Object { $_ -eq $legacy } | Select-Object -First 1 }
if (-not $asset) { throw "install: no release asset for windows/$arch (looked for *$suffix or $legacy)" }

$work = Join-Path $env:TEMP ("bcc-vibe-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
  # Asset bytes need the octet-stream Accept; the API URL 302s to the CDN.
  $dl = @{ Authorization = "Bearer $Token"; Accept = "application/octet-stream" }
  $assetObj = $release.assets | Where-Object { $_.name -eq $asset } | Select-Object -First 1
  $zipPath = Join-Path $work $asset
  Write-Host "install: downloading $asset"
  Invoke-WebRequest -Headers $dl -Uri $assetObj.url -OutFile $zipPath

  $checksums = $release.assets | Where-Object { $_.name -eq "checksums.txt" } | Select-Object -First 1
  if ($checksums) {
    $sumPath = Join-Path $work "checksums.txt"
    Invoke-WebRequest -Headers $dl -Uri $checksums.url -OutFile $sumPath
    $line = Get-Content $sumPath | Where-Object { $_ -match ("\*?" + [regex]::Escape($asset) + "$") } | Select-Object -First 1
    if (-not $line) { throw "install: no checksum entry for $asset" }
    $expected = ($line -split "\s+")[0].ToLower()
    $actual = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLower()
    if ($actual -ne $expected) { throw "install: checksum mismatch for $asset" }
    Write-Host "install: checksum verified"
  } else {
    Write-Host "install: warning - release has no checksums.txt, skipping integrity check"
  }

  Expand-Archive -Path $zipPath -DestinationPath $work -Force
  $exe = Join-Path $work "bcc-vibe.exe"
  if (-not (Test-Path $exe)) { throw "install: archive $asset did not contain bcc-vibe.exe at its root" }

  $bindir = if ($env:VIBE_INSTALL_DIR) { $env:VIBE_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "Programs\Vibe" }
  New-Item -ItemType Directory -Path $bindir -Force | Out-Null
  Move-Item -Path $exe -Destination (Join-Path $bindir "bcc-vibe.exe") -Force
  Write-Host "install: installed $bindir\bcc-vibe.exe"

  # Add to the user PATH if missing (new shells pick it up).
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (($userPath -split ";") -notcontains $bindir) {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$bindir", "User")
    Write-Host "install: added $bindir to your user PATH (restart the shell to pick it up)"
  }
  Write-Host "Next: bcc-vibe setup"
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
