param(
    [Parameter(Mandatory = $true)]
    [string]$Kernel32Lib,

    [Parameter(Mandatory = $true)]
    [string]$Target,

    [Parameter(Mandatory = $true)]
    [string]$WorkDir,

    [Parameter(Mandatory = $true)]
    [string]$OutputLib
)

$ErrorActionPreference = 'Stop'

# Keep this provider intentionally narrow. These are the exact post-XP API
# names observed in the 2026-08-30 XP x86 import audit, plus four already
# proven modern-Rust compatibility entries retained from run 33138244191.
$apiBytes = [ordered]@{
    AcquireSRWLockExclusive             = 4
    AcquireSRWLockShared                = 4
    CancelIoEx                          = 8
    CompareStringOrdinal                = 20
    FlsAlloc                            = 4
    FlsFree                             = 4
    FlsGetValue                         = 4
    FlsSetValue                         = 8
    GetCurrentProcessorNumber           = 0
    GetFileInformationByHandleEx        = 16
    GetFinalPathNameByHandleW            = 16
    GetLocaleInfoEx                     = 16
    GetSystemTimePreciseAsFileTime      = 4
    GetTickCount64                      = 0
    InitializeConditionVariable         = 4
    InitializeCriticalSectionEx         = 12
    InitializeSRWLock                   = 4
    IsThreadAFiber                      = 0
    LCIDToLocaleName                    = 16
    LocaleNameToLCID                    = 8
    ProcessPrng                         = 8
    ReleaseSRWLockExclusive             = 4
    ReleaseSRWLockShared                = 4
    SetFileInformationByHandle          = 16
    SetThreadStackGuarantee             = 4
    SleepConditionVariableCS            = 12
    SleepConditionVariableSRW           = 16
    TryAcquireSRWLockExclusive          = 4
    WakeAllConditionVariable            = 4
    WakeConditionVariable               = 4
}

if (-not (Test-Path -LiteralPath $Kernel32Lib)) {
    throw "YY kernel32.lib not found: $Kernel32Lib"
}

$selected = Join-Path $WorkDir 'selected'
if (Test-Path -LiteralPath $WorkDir) {
    Remove-Item -Recurse -Force -LiteralPath $WorkDir
}
New-Item -ItemType Directory -Force $selected | Out-Null

$members = @(
    & lib.exe /nologo /list $Kernel32Lib 2>&1 |
        ForEach-Object { "$_".Trim() } |
        Where-Object { $_ } |
        Select-Object -Unique
)
if ($LASTEXITCODE -ne 0 -or $members.Count -eq 0) {
    throw 'Cannot enumerate YY XP x86 kernel32.lib'
}
$members | Set-Content -Encoding utf8 (Join-Path $WorkDir 'yy-kernel32-members.txt')

function Extract-One([string]$Member, [string]$Key) {
    $dir = Join-Path $selected $Key
    New-Item -ItemType Directory -Force $dir | Out-Null
    Push-Location $dir
    try {
        & lib.exe /nologo "/extract:$Member" $Kernel32Lib *> extract.log
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to extract $Member"
        }
    } finally {
        Pop-Location
    }

    $file = Get-ChildItem -LiteralPath $dir -File |
        Where-Object { $_.Name -ne 'extract.log' } |
        Sort-Object Length -Descending |
        Select-Object -First 1
    if (-not $file) {
        throw "No extracted object for $Key"
    }

    $dst = Join-Path $dir 'member.obj'
    Copy-Item -Force $file.FullName $dst
    (& dumpbin.exe /nologo /symbols $dst 2>&1 | Out-String) |
        Set-Content -Encoding utf8 (Join-Path $dir 'symbols.txt')
    return $dst
}

$objects = [System.Collections.Generic.List[string]]::new()
$mapping = [System.Collections.Generic.List[string]]::new()

foreach ($entry in $apiBytes.GetEnumerator()) {
    $api = $entry.Key
    $bytes = [int]$entry.Value
    foreach ($kind in @('obj', 'obi')) {
        $pattern = '(?i)(?:^|[\\/])_' + [regex]::Escape($api) + '@' + $bytes + '\.' + $kind + '$'
        $matches = @($members | Where-Object { $_ -match $pattern })
        if ($matches.Count -ne 1) {
            throw "Expected one $api .$kind member for stdcall @$bytes; found $($matches.Count)"
        }
        $objects.Add((Extract-One $matches[0] "$api-$kind"))
        $mapping.Add("$api-$kind|$($matches[0])")
    }
}

$implementationPattern = '(?i)(?:^|[\\/])YY_Thunks_for_' + [regex]::Escape($Target) + '\.obj$'
$implementation = @($members | Where-Object { $_ -match $implementationPattern })
if ($implementation.Count -ne 1) {
    throw "Expected one common YY implementation for $Target; found $($implementation.Count)"
}
$objects.Add((Extract-One $implementation[0] 'implementation'))
$mapping.Add("implementation|$($implementation[0])")
$mapping | Set-Content -Encoding utf8 (Join-Path $WorkDir 'selected-members.txt')

& lib.exe /nologo "/out:$OutputLib" @($objects)
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputLib)) {
    throw 'Failed to build narrow YY XP x86 provider'
}

$symbols = (& dumpbin.exe /nologo /linkermember:1 $OutputLib 2>&1 | Out-String)
$symbols | Set-Content -Encoding utf8 (Join-Path $WorkDir 'narrow-provider-symbols.txt')
foreach ($api in $apiBytes.Keys) {
    $required = "YY_Thunks_$api"
    if ($symbols.IndexOf($required, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Narrow provider missing $required"
    }
}

# Positive control from the historical coexistence smoke: a full kernel32.lib
# interposition would expose unrelated symbols such as LockResource. The narrow
# archive must not do that.
foreach ($broad in @('LockResource', '__imp_LockResource', 'YY_Thunks_LockResource')) {
    if ($symbols -match ('(?m)(?:^|\s)' + [regex]::Escape($broad) + '\s*$')) {
        throw "Narrow provider exposes unrelated broad symbol $broad"
    }
}

Write-Output $OutputLib
