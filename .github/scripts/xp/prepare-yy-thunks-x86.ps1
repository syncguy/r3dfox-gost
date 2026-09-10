$ErrorActionPreference = 'Stop'

$release = Invoke-RestMethod -Headers @{ 'User-Agent' = 'r3dfox-gost-ci' } -Uri "https://api.github.com/repos/Chuyu-Team/YY-Thunks/releases/tags/v$env:YY_THUNKS_VERSION"
$asset = $release.assets | Where-Object { $_.name -match '(?i)Lib.*\.zip$|(?i)-Lib\.zip$' } | Select-Object -First 1
if (-not $asset) {
  throw "YY-Thunks v$env:YY_THUNKS_VERSION Lib asset not found"
}

$zip = Join-Path $env:RUNNER_TEMP $asset.name
$root = Join-Path $env:RUNNER_TEMP 'yy-thunks-xp-x86'
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
if (Test-Path $root) {
  Remove-Item -Recurse -Force $root
}
Expand-Archive -Path $zip -DestinationPath $root

$targetPattern = [regex]::Escape($env:YY_THUNKS_TARGET)
$yyLib = Get-ChildItem -Path $root -Recurse -Directory |
  Where-Object { $_.FullName -match "(?i)[\\/]Lib[\\/]$targetPattern[\\/]x86$" } |
  Select-Object -First 1
if (-not $yyLib) {
  throw "YY-Thunks Lib/$env:YY_THUNKS_TARGET/x86 not found"
}

$kernel32 = Join-Path $yyLib.FullName 'kernel32.lib'
$synch = Join-Path $yyLib.FullName 'synchronization.lib'
$ws2 = Join-Path $yyLib.FullName 'ws2_32.lib'
if (-not (Test-Path $kernel32) -or -not (Test-Path $synch) -or -not (Test-Path $ws2)) {
  throw 'Required YY XP x86 libraries are missing'
}

"THUNK_YY_LIB=$($yyLib.FullName)" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"THUNK_YY_KERNEL32_LIB=$kernel32" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"THUNK_YY_SYNCH_LIB=$synch" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"THUNK_YY_WS2_32_LIB=$ws2" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
