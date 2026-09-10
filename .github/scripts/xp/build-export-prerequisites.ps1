$ErrorActionPreference = 'Stop'

$mozmake = Join-Path $env:USERPROFILE '.mozbuild\mozmake\mozmake.exe'
& $mozmake -C $env:OBJDIR recurse_pre-export
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

& $mozmake -C $env:OBJDIR recurse_export
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
