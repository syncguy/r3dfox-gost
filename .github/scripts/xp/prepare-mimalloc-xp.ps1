param(
  [Parameter(Mandatory = $true)][string]$MimallocRoot,
  [Parameter(Mandatory = $true)][string]$ExpectedSha,
  [Parameter(Mandatory = $true)][string]$DiagnosticsDir
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$actualSha = (git -C $MimallocRoot rev-parse HEAD).Trim()
if ($actualSha -ne $ExpectedSha) {
  throw "mimalloc XP overlay expected $ExpectedSha but checkout is $actualSha"
}

function Replace-RegexOnce([string]$Path, [string]$Pattern, [string]$Replacement, [string]$Description) {
  $text = [System.IO.File]::ReadAllText($Path)
  $matches = [regex]::Matches($text, $Pattern)
  if ($matches.Count -ne 1) {
    throw "mimalloc XP overlay '$Description' expected exactly one source match, found $($matches.Count) in $Path"
  }
  $updated = [regex]::Replace($text, $Pattern, $Replacement, 1)
  [System.IO.File]::WriteAllText($Path, $updated, $utf8NoBom)
}

$atomicPath = Join-Path $MimallocRoot 'include\mimalloc\atomic.h'
$primPath = Join-Path $MimallocRoot 'src\prim\windows\prim.c'

# SRWLOCK is unavailable on XP. For _WIN32_WINNT=0x0501 use mimalloc's
# existing portable atomic lock implementation instead of importing SRW APIs.
Replace-RegexOnce -Path $atomicPath -Pattern '#if defined\(_WIN32\)(\r?\n\r?\ntypedef struct mi_lock_s)' -Replacement '#if defined(_WIN32) && !defined(MI_XP_COMPAT)$1' -Description 'XP lock fallback'

# Mimalloc already resolves the surrounding NUMA APIs dynamically. Do the same
# for GetCurrentProcessorNumber so an XP process does not carry a direct import.
$typedefReplacement = 'typedef DWORD (__stdcall *PGetCurrentProcessorNumber)(VOID);' + [Environment]::NewLine + 'typedef VOID (__stdcall *PGetCurrentProcessorNumberEx)(MI_PROCESSOR_NUMBER* ProcNumber);'
Replace-RegexOnce -Path $primPath -Pattern 'typedef VOID \(__stdcall \*PGetCurrentProcessorNumberEx\)\(MI_PROCESSOR_NUMBER\* ProcNumber\);' -Replacement $typedefReplacement -Description 'GetCurrentProcessorNumber typedef'

$pointerReplacement = 'static PGetCurrentProcessorNumber   pGetCurrentProcessorNumber   = NULL;' + [Environment]::NewLine + 'static PGetCurrentProcessorNumberEx pGetCurrentProcessorNumberEx = NULL;'
Replace-RegexOnce -Path $primPath -Pattern 'static PGetCurrentProcessorNumberEx pGetCurrentProcessorNumberEx = NULL;' -Replacement $pointerReplacement -Description 'GetCurrentProcessorNumber pointer'

$lookupReplacement = 'pGetCurrentProcessorNumber = (PGetCurrentProcessorNumber)(void (*)(void))GetProcAddress(hDll, "GetCurrentProcessorNumber");' + [Environment]::NewLine + '    pGetCurrentProcessorNumberEx = (PGetCurrentProcessorNumberEx)(void (*)(void))GetProcAddress(hDll, "GetCurrentProcessorNumberEx");'
Replace-RegexOnce -Path $primPath -Pattern 'pGetCurrentProcessorNumberEx = \(PGetCurrentProcessorNumberEx\)\(void \(\*\)\(void\)\)GetProcAddress\(hDll, "GetCurrentProcessorNumberEx"\);' -Replacement $lookupReplacement -Description 'GetCurrentProcessorNumber dynamic lookup'

Replace-RegexOnce -Path $primPath -Pattern 'else if \(pGetNumaProcessorNode != NULL\) \{(\r?\n\s*// Vista or earlier, use older API that is limited to 64 processors\. Issue #277\r?\n\s*)DWORD pnum = GetCurrentProcessorNumber\(\);' -Replacement 'else if (pGetNumaProcessorNode != NULL && pGetCurrentProcessorNumber != NULL) {$1DWORD pnum = (*pGetCurrentProcessorNumber)();' -Description 'GetCurrentProcessorNumber indirect call'

$diffPath = Join-Path $DiagnosticsDir 'mimalloc-2.5.2-xp-overlay.diff'
$diff = @(git -C $MimallocRoot diff -- include/mimalloc/atomic.h src/prim/windows/prim.c)
if ($LASTEXITCODE -ne 0) {
  throw "git diff failed for mimalloc XP overlay: $LASTEXITCODE"
}
$diff | Set-Content -Encoding utf8 $diffPath

$status = @(git -C $MimallocRoot status --porcelain)
$unexpected = @($status | Where-Object {
  $_ -notmatch '^ M include/mimalloc/atomic\.h$' -and
  $_ -notmatch '^ M src/prim/windows/prim\.c$'
})
if ($unexpected.Count) {
  throw "Unexpected mimalloc XP overlay changes: $($unexpected -join '; ')"
}
if ($status.Count -ne 2) {
  throw "mimalloc XP overlay expected exactly two modified files, got: $($status -join '; ')"
}

"mimalloc_xp_overlay_base=$actualSha" | Add-Content (Join-Path $DiagnosticsDir 'identity.txt')
