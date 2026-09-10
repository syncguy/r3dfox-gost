$ErrorActionPreference = 'Stop'

$active = @(Get-CimInstance Win32_PageFileUsage)
$activeMB = ($active | Measure-Object -Property AllocatedBaseSize -Sum).Sum
if ($null -eq $activeMB) {
  $activeMB = 0
}

if ($activeMB -ge 20480) {
  'need=false' | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
  exit 0
}

$activeRoots = @($active | ForEach-Object {
  if ($_.Name -match '^([A-Za-z]:)\\') {
    $matches[1].ToUpperInvariant()
  }
})

$candidate = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
  Where-Object { ($activeRoots -notcontains $_.DeviceID.ToUpperInvariant()) -and $_.FreeSpace -ge 30GB } |
  Sort-Object FreeSpace -Descending |
  Select-Object -First 1

if (-not $candidate) {
  throw 'No non-active fixed drive with at least 30 GB free was found for pagefile.'
}

'need=true' | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"disk=$($candidate.DeviceID)" | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
