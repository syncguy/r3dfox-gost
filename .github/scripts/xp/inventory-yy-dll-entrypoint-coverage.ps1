$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force diagnostics | Out-Null
$bin = (Resolve-Path (Join-Path $env:OBJDIR 'dist\bin')).Path
$reportPath = Join-Path $env:GITHUB_WORKSPACE 'diagnostics\yy-dll-entrypoint-audit.txt'
$missingPath = Join-Path $env:GITHUB_WORKSPACE 'diagnostics\yy-dll-entrypoint-missing-contract.txt'

function Read-U16([byte[]]$Data, [int]$Offset) {
  if ($Offset -lt 0 -or ($Offset + 2) -gt $Data.Length) { throw "PE read U16 out of range at $Offset" }
  return [BitConverter]::ToUInt16($Data, $Offset)
}
function Read-U32([byte[]]$Data, [int]$Offset) {
  if ($Offset -lt 0 -or ($Offset + 4) -gt $Data.Length) { throw "PE read U32 out of range at $Offset" }
  return [BitConverter]::ToUInt32($Data, $Offset)
}
function Convert-RvaToFileOffset([byte[]]$Data, [int]$SectionTable, [int]$SectionCount, [uint32]$Rva) {
  for ($i = 0; $i -lt $SectionCount; $i++) {
    $section = $SectionTable + (40 * $i)
    $virtualSize = Read-U32 $Data ($section + 8)
    $virtualAddress = Read-U32 $Data ($section + 12)
    $rawSize = Read-U32 $Data ($section + 16)
    $rawPointer = Read-U32 $Data ($section + 20)
    $span = [Math]::Max([uint64]$virtualSize, [uint64]$rawSize)
    $rva64 = [uint64]$Rva
    $va64 = [uint64]$virtualAddress
    if ($rva64 -ge $va64 -and $rva64 -lt ($va64 + $span)) {
      return [int]([uint64]$rawPointer + ($rva64 - $va64))
    }
  }
  throw ("Cannot map RVA 0x{0:X8}" -f $Rva)
}
function Test-FixedBytes([byte[]]$Data, [int]$Offset, [hashtable]$Expected) {
  foreach ($key in $Expected.Keys) {
    $index = $Offset + [int]$key
    if ($index -lt 0 -or $index -ge $Data.Length -or $Data[$index] -ne [byte]$Expected[$key]) { return $false }
  }
  return $true
}

$entryFingerprint = @{
  0=0x53; 1=0x56; 2=0x57; 3=0x8B; 4=0x3D;
  9=0x85; 10=0xFF; 11=0x75; 12=0x05; 13=0xBF;
  18=0x8B; 19=0x44; 20=0x24; 21=0x14; 22=0x83; 23=0xE8; 24=0x00
}
$firstCallbackFingerprint = @{
  0=0x33; 1=0xC0; 2=0x40; 3=0x39; 4=0x44; 5=0x24; 6=0x08;
  7=0x75; 8=0x0E; 9=0x83; 10=0x3D; 15=0x00; 16=0x75; 17=0x05;
  18=0xA3; 23=0xC2; 24=0x0C; 25=0x00
}

function Get-YyDllContract([byte[]]$Data, [string]$Path) {
  if ($Data.Length -lt 0x100) { throw "PE too small: $Path" }
  $peOffset = [int](Read-U32 $Data 0x3C)
  if (($peOffset + 24) -gt $Data.Length) { throw "Invalid PE offset: $Path" }
  if ($Data[$peOffset] -ne 0x50 -or $Data[$peOffset + 1] -ne 0x45 -or $Data[$peOffset + 2] -ne 0 -or $Data[$peOffset + 3] -ne 0) { throw "Missing PE signature: $Path" }
  $coff = $peOffset + 4
  $machine = Read-U16 $Data $coff
  if ($machine -ne 0x14C) { return [pscustomobject]@{ X86=$false; EntryWrapper=$false; FirstTlsCallback=$false } }
  $sectionCount = [int](Read-U16 $Data ($coff + 2))
  $optionalSize = [int](Read-U16 $Data ($coff + 16))
  $optional = $coff + 20
  if ((Read-U16 $Data $optional) -ne 0x10B) { throw "Expected PE32 optional header: $Path" }
  $entryRva = Read-U32 $Data ($optional + 16)
  $imageBase = Read-U32 $Data ($optional + 28)
  $sectionTable = $optional + $optionalSize

  $entryWrapper = $false
  if ($entryRva -ne 0) {
    $entryOffset = Convert-RvaToFileOffset $Data $sectionTable $sectionCount $entryRva
    $entryWrapper = Test-FixedBytes $Data $entryOffset $entryFingerprint
  }

  $firstTlsCallback = $false
  $numberOfRvaAndSizes = Read-U32 $Data ($optional + 92)
  if ($numberOfRvaAndSizes -gt 9) {
    $tlsRva = Read-U32 $Data ($optional + 96 + (9 * 8))
    if ($tlsRva -ne 0) {
      $tlsOffset = Convert-RvaToFileOffset $Data $sectionTable $sectionCount $tlsRva
      $callbacksVa = Read-U32 $Data ($tlsOffset + 12)
      if ([uint64]$callbacksVa -ge [uint64]$imageBase -and $callbacksVa -ne 0) {
        $callbacksRva = [uint32]([uint64]$callbacksVa - [uint64]$imageBase)
        $callbacksOffset = Convert-RvaToFileOffset $Data $sectionTable $sectionCount $callbacksRva
        for ($i = 0; $i -lt 32; $i++) {
          $callbackVa = Read-U32 $Data ($callbacksOffset + (4 * $i))
          if ($callbackVa -eq 0) { break }
          if ([uint64]$callbackVa -lt [uint64]$imageBase) { continue }
          $callbackRva = [uint32]([uint64]$callbackVa - [uint64]$imageBase)
          try {
            $callbackOffset = Convert-RvaToFileOffset $Data $sectionTable $sectionCount $callbackRva
            if (Test-FixedBytes $Data $callbackOffset $firstCallbackFingerprint) { $firstTlsCallback = $true; break }
          } catch { }
        }
      }
    }
  }
  return [pscustomobject]@{ X86=$true; EntryWrapper=$entryWrapper; FirstTlsCallback=$firstTlsCallback }
}

$trackedApis = @(
  'ProcessPrng','GetSystemTimePreciseAsFileTime','FlsAlloc','FlsFree','FlsSetValue',
  'IsThreadAFiber','SetThreadStackGuarantee','AcquireSRWLockExclusive','AcquireSRWLockShared',
  'ReleaseSRWLockExclusive','ReleaseSRWLockShared','InitializeSRWLock','InitializeConditionVariable',
  'SleepConditionVariableCS','SleepConditionVariableSRW','WakeAllConditionVariable','WakeConditionVariable',
  'GetTickCount64','InitializeCriticalSectionEx','CompareStringOrdinal','GetCurrentProcessorNumber',
  'GetFileInformationByHandleEx','GetFinalPathNameByHandleW','GetLocaleInfoEx','LCIDToLocaleName',
  'LocaleNameToLCID','SetFileInformationByHandle','CancelIoEx','CreateWaitableTimerExW',
  'CancelSynchronousIo','GetDynamicTimeZoneInformation','GetProcessIdOfThread','GetQueuedCompletionStatusEx',
  'GetThreadId','GetTimeZoneInformationForYear','GetUserPreferredUILanguages','GetThreadPreferredUILanguages',
  'InitOnceExecuteOnce','InitOnceBeginInitialize','InitOnceComplete','QueryFullProcessImageNameA',
  'QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime','TryAcquireSRWLockExclusive','FlsGetValue',
  'NtCancelIoFileEx','EventRegister','EventUnregister','EventWrite','EventWriteTransfer','RegGetValueW','WSAIoctl','inet_ntop'
)

$report = [System.Collections.Generic.List[string]]::new()
$missing = [System.Collections.Generic.List[string]]::new()
$strongCount = 0
$contractCount = 0
$xulPositiveControl = $false
$dlls = @(Get-ChildItem -LiteralPath $bin -Recurse -File -Filter '*.dll' | Sort-Object FullName)
foreach ($dll in $dlls) {
  $relative = $dll.FullName.Substring($bin.Length).TrimStart('\') -replace '\\','/'
  try {
    $bytes = [System.IO.File]::ReadAllBytes($dll.FullName)
    $pe = Get-YyDllContract $bytes $dll.FullName
    if (-not $pe.X86) {
      $report.Add("dll=$relative|classification=SKIP_NON_X86")
      continue
    }
    $imports = @(& dumpbin.exe /nologo /imports $dll.FullName 2>&1)
    $dumpbinExit = $LASTEXITCODE
    if ($dumpbinExit -ne 0) {
      $report.Add("dll=$relative|classification=INCONCLUSIVE_IMPORT_SCAN|dumpbin_exit=$dumpbinExit")
      continue
    }
    $importText = $imports -join "`n"
    $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
    $resolverHits = [System.Collections.Generic.List[string]]::new()
    foreach ($api in $trackedApis) {
      if ($ascii.IndexOf($api, [System.StringComparison]::Ordinal) -lt 0) { continue }
      if ($importText.IndexOf($api, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { continue }
      $resolverHits.Add($api)
    }
    $strong = $resolverHits.Count -ge 2
    $contract = [bool]($pe.EntryWrapper -and $pe.FirstTlsCallback)
    if ($strong) { $strongCount++ }
    if ($contract) { $contractCount++ }
    if ($strong -and $contract) { $classification = 'YY_CANDIDATE_CONTRACT_PRESENT' }
    elseif ($strong) { $classification = 'YY_CANDIDATE_CONTRACT_MISSING' }
    elseif ($contract) { $classification = 'YY_CONTRACT_PRESENT_NO_STRONG_RESOLVER_EVIDENCE' }
    else { $classification = 'NO_STRONG_YY_RESOLVER_EVIDENCE' }
    $hash = (Get-FileHash -Algorithm SHA256 $dll.FullName).Hash.ToLowerInvariant()
    $report.Add("dll=$relative|sha256=$hash|resolver_nonimport_hits=$($resolverHits.Count)|entry_wrapper=$($pe.EntryWrapper.ToString().ToLowerInvariant())|yy_first_tls_callback=$($pe.FirstTlsCallback.ToString().ToLowerInvariant())|contract=$($contract.ToString().ToLowerInvariant())|classification=$classification|apis=$($resolverHits -join ',')")
    if ($classification -eq 'YY_CANDIDATE_CONTRACT_MISSING') { $missing.Add("$relative|apis=$($resolverHits -join ',')") }
    if ($relative -ieq 'xul.dll' -and $strong -and $contract) { $xulPositiveControl = $true }
  } catch {
    $report.Add("dll=$relative|classification=INCONCLUSIVE_EXCEPTION|message=$($_.Exception.Message -replace '[\r\n]+',' ')")
  } finally {
    Remove-Variable ascii,bytes -ErrorAction SilentlyContinue
  }
}

$header = @(
  "source=$env:GITHUB_SHA",
  'scope=dist/bin/**/*.dll',
  'mode=non-blocking heuristic inventory',
  'strong_candidate_rule=at least two tracked YY-provider API strings absent from ordinary/delay import dump',
  'contract_rule=YY v1.2.2 x86 entry-wrapper fingerprint AND YY FirstCallback TLS fingerprint',
  "xul_positive_control=$($xulPositiveControl.ToString().ToLowerInvariant())",
  "strong_candidates=$strongCount",
  "contracts_present=$contractCount",
  "missing_contract_candidates=$($missing.Count)"
)
@($header + $report) | Set-Content -Encoding utf8 $reportPath
if ($missing.Count -gt 0) { $missing | Set-Content -Encoding utf8 $missingPath } else { 'none' | Set-Content -Encoding utf8 $missingPath }

Write-Host "YY DLL inventory: strong candidates=$strongCount, contracts=$contractCount, missing-contract candidates=$($missing.Count)"
if (-not $xulPositiveControl) { Write-Warning 'xul.dll did not satisfy the known-good YY wrapper/TLS callback positive control; treat this diagnostic as inconclusive.' }
if ($missing.Count -gt 0) {
  Write-Warning 'Strong YY resolver candidates without the DLL entry-point/TLS contract were found. This is evidence for follow-up, not proof that any physical XP crash is caused by YY-Thunks.'
  $missing | ForEach-Object { Write-Warning $_ }
}
