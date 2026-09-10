$ErrorActionPreference = 'Stop'

$output = .\mach.ps1 configure 2>&1
$exitCode = $LASTEXITCODE
$output | Tee-Object -FilePath configure-xp-x32.log
if ($exitCode -ne 0) {
  exit $exitCode
}

$joined = $output -join "`n"
if ($joined -notmatch 'checking for rust target triplet\.\.\.\s+i686-pc-windows-msvc') {
  throw 'XP x32 build did not select i686-pc-windows-msvc Rust target.'
}
