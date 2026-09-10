$ErrorActionPreference = 'Stop'

$mozmake = Join-Path $env:USERPROFILE '.mozbuild\mozmake\mozmake.exe'
& $mozmake -C $env:OBJDIR 'security/manager/ssl/target-objects'
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
