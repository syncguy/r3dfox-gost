$ErrorActionPreference = 'Stop'

$path = 'toolkit\library\moz.build'
$text = [System.IO.File]::ReadAllText($path)
foreach ($required in @(
  '-ENTRY:DllMainCRTStartupForYY_Thunks',
  '-alternatename:_YY_ThunksOriginalDllMainCRTStartup@12=__DllMainCRTStartup@12'
)) {
  if ($text.IndexOf($required, [System.StringComparison]::Ordinal) -lt 0) {
    throw "Committed xul.dll YY TLS entry-point contract missing linker flag: $required"
  }
}

New-Item -ItemType Directory -Force diagnostics | Out-Null
@(
  'scope=toolkit/library Libxul xul-real only',
  'source_mode=committed',
  'entry=-ENTRY:DllMainCRTStartupForYY_Thunks',
  'alternate=-alternatename:_YY_ThunksOriginalDllMainCRTStartup@12=__DllMainCRTStartup@12',
  'global_target_ldflags=unchanged',
  'result=PASS'
) | Set-Content -Encoding utf8 diagnostics\xul-yy-dll-entrypoint-source.txt
