$ErrorActionPreference = 'Stop'

$requiredFlags = @(
  '-ENTRY:DllMainCRTStartupForYY_Thunks',
  '-alternatename:_YY_ThunksOriginalDllMainCRTStartup@12=__DllMainCRTStartup@12'
)

$contracts = @(
  @{
    Path = 'toolkit\library\moz.build'
    Scope = 'toolkit/library Libxul xul-real'
  },
  @{
    Path = 'gfx\angle\targets\libGLESv2\moz.build'
    Scope = 'gfx/angle libGLESv2 Windows x86'
  }
)

foreach ($contract in $contracts) {
  $text = [System.IO.File]::ReadAllText($contract.Path)
  foreach ($required in $requiredFlags) {
    if ($text.IndexOf($required, [System.StringComparison]::Ordinal) -lt 0) {
      throw "Committed YY TLS entry-point contract missing linker flag in $($contract.Path): $required"
    }
  }
}

New-Item -ItemType Directory -Force diagnostics | Out-Null
@(
  'scope=toolkit/library Libxul xul-real; gfx/angle libGLESv2 Windows x86',
  'source_mode=committed',
  'entry=-ENTRY:DllMainCRTStartupForYY_Thunks',
  'alternate=-alternatename:_YY_ThunksOriginalDllMainCRTStartup@12=__DllMainCRTStartup@12',
  'global_target_ldflags=unchanged',
  'result=PASS'
) | Set-Content -Encoding utf8 diagnostics\yy-dll-entrypoint-source.txt
