param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('run')]
    [string]$Stage
)

switch ($Stage) {
    'run' {
$ErrorActionPreference='Stop'
$members=@(& lib.exe /nologo /list $env:THUNK_YY_NTDLL_LIB 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique)
if($LASTEXITCODE-ne 0-or-not$members.Count){throw 'Cannot enumerate YY ntdll.lib'}
$members|Set-Content -Encoding utf8 diagnostics\yy-ntdll-members.txt
$api='NtCancelIoFileEx';$escaped=[regex]::Escape($api);$objects=@();$selected=Join-Path $env:RUNNER_TEMP 'yy-ntcancel-selected';if(Test-Path $selected){Remove-Item -Recurse -Force $selected};New-Item -ItemType Directory -Force $selected|Out-Null
$report=[System.Collections.Generic.List[string]]::new();$report.Add("API`tDirectMember`tImportMember`tYYSymbol`tProviderCapability")
$direct=@($members|Where-Object{$_-match"(?i)[\\/]_${escaped}@12\.obj$"});$import=@($members|Where-Object{$_-match"(?i)[\\/]_${escaped}@12\.obi$"})
if($direct.Count-ne 1-or$import.Count-ne 1){$report.Add("$api`t$($direct -join ',')`t$($import -join ',')`tfalse`tmissing");$report|Set-Content -Encoding utf8 diagnostics\yy-ntdll-capability.tsv;throw "YY ntdll.lib does not expose the expected $api x86 members"}
foreach($spec in @(@{Kind='obj';Member=$direct[0]},@{Kind='obi';Member=$import[0]})){
  $dir=Join-Path $selected "ntcancel-$($spec.Kind)"
  New-Item -ItemType Directory -Force $dir|Out-Null
  Push-Location $dir
  try{
    & lib.exe /nologo "/extract:$($spec.Member)" $env:THUNK_YY_NTDLL_LIB|Out-Null
    if($LASTEXITCODE-ne 0){throw "NtCancelIoFileEx $($spec.Kind) extraction failed"}
  }finally{Pop-Location}
  $file=Get-ChildItem $dir -File -Filter "*.$($spec.Kind)"|Select-Object -First 1
  if(-not$file){throw "Missing extracted NtCancelIoFileEx $($spec.Kind) object"}
  $dst=Join-Path $dir 'member.obj'
  Copy-Item -Force $file.FullName $dst
  $objects+=$dst
}
# Reuse the common YY implementation already linked in the KERNEL32 narrow provider.
# ntdll.lib for this XP target carries only NtCancelIoFileEx weak-alias members.
$narrow=Join-Path $env:RUNNER_TEMP 'yy-xp-ntcancel.lib';& lib.exe /nologo "/out:$narrow" @objects;if($LASTEXITCODE-ne 0){throw 'NtCancelIoFileEx narrow provider build failed'}
$symbols=(& dumpbin.exe /nologo /linkermember:1 $narrow 2>&1|Out-String)
$symbols|Set-Content -Encoding utf8 diagnostics\ntcancel-provider-symbols.txt
$shared=(& dumpbin.exe /nologo /linkermember:1 $env:NARROW_YY_LIB 2>&1|Out-String)
$shared|Set-Content -Encoding utf8 diagnostics\ntcancel-shared-provider-symbols.txt
foreach($symbol in @('_NtCancelIoFileEx@12','__imp__NtCancelIoFileEx@12')){
  if($symbols.IndexOf(" $symbol",[System.StringComparison]::Ordinal)-lt 0){
    throw "NtCancelIoFileEx alias provider missing $symbol"
  }
}
foreach($symbol in @('_YY_Thunks_NtCancelIoFileEx@12','_YY_Thunks_ProcessPrng@8')){
  if($shared.IndexOf(" $symbol",[System.StringComparison]::Ordinal)-lt 0){
    throw "Shared KERNEL32 narrow provider missing $symbol"
  }
}
foreach($entry in (Get-Content diagnostics\winrt-closure-apis.txt)){
  foreach($prefix in @('_YY_Thunks_','__imp__YY_Thunks_')){
    if($shared.IndexOf(" $prefix$entry",[System.StringComparison]::Ordinal)-lt 0){
      throw "Shared KERNEL32 narrow provider missing WinRT symbol $prefix$entry"
    }
  }
}
$report.Add("$api`t$($direct[0])`t$($import[0])`ttrue`tcapable")
$report|Set-Content -Encoding utf8 diagnostics\yy-ntdll-capability.tsv
@'
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
typedef LONG NTSTATUS;
typedef struct _IO_STATUS_BLOCK { union { NTSTATUS Status; PVOID Pointer; }; ULONG_PTR Information; } IO_STATUS_BLOCK, *PIO_STATUS_BLOCK;
extern "C" NTSTATUS NTAPI NtCancelIoFileEx(HANDLE, PIO_STATUS_BLOCK, PIO_STATUS_BLOCK);
int main(){WCHAR p[MAX_PATH];DWORD n=GetTempPathW(MAX_PATH,p);const WCHAR s[]=L"r3dfox-yy-ntcancel.tmp";DWORD i=n;for(DWORD j=0;s[j]&&i+1<MAX_PATH;++j)p[i++]=s[j];p[i]=0;HANDLE f=CreateFileW(p,GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,0,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL|FILE_FLAG_DELETE_ON_CLOSE,0);if(f==INVALID_HANDLE_VALUE){return 2;}IO_STATUS_BLOCK iosb={};NTSTATUS st=NtCancelIoFileEx(f,0,&iosb);CloseHandle(f);if(st==0||(ULONG)st==0xC0000225UL){printf("NtCancelIoFileEx: PASS status=0x%08lX\n",(ULONG)st);return 0;}printf("NtCancelIoFileEx: FAIL status=0x%08lX\n",(ULONG)st);return 1;}
'@|Set-Content -Encoding ascii ntcancel.cpp
& cl.exe /nologo /c /MD /O2 /GS- /EHsc- /GR- ntcancel.cpp /Fontcancel.obj 2>&1|Tee-Object diagnostics\ntcancel-compile.log;if($LASTEXITCODE-ne 0){throw 'NtCancelIoFileEx probe compile failed'}
$lld=(Get-Command lld-link.exe -ErrorAction SilentlyContinue).Source;if(-not$lld){$lld='C:\Program Files\LLVM\bin\lld-link.exe'};if(-not(Test-Path $lld)){throw 'lld-link missing'}
$exe=(Resolve-Path runtime).Path+'\xp-ntcanceliofileex.exe';$map=(Resolve-Path diagnostics).Path+'\ntcancel.map'
$args=@("-LIBPATH:$env:MSVCR14X_RELEASE",$env:THUNK_YY_SYNCH_LIB,$env:NARROW_YY_LIB,$narrow,
  '/nodefaultlib:runtimeobject.lib',
  'ntcancel.obj','/subsystem:console','/entry:mainCRTStartup',"/map:$map","/out:$exe")
foreach($entry in (Get-Content diagnostics\winrt-closure-apis.txt)){
  $args+="/alternatename:_$entry=_YY_Thunks_$entry"
  $args+="/alternatename:__imp__$entry=__imp__YY_Thunks_$entry"
}
($lld+' '+($args-join' '))|Set-Content -Encoding utf8 diagnostics\ntcancel-link-command.txt
& $lld @args 2>&1|Tee-Object diagnostics\ntcancel-link-output.txt
if($LASTEXITCODE-ne 0-or-not(Test-Path $exe)){throw 'NtCancelIoFileEx link failed'}
& editbin.exe /nologo "/SUBSYSTEM:CONSOLE,$env:WINDOWS_XP_SUBSYSTEM" $exe|Out-Null;if($LASTEXITCODE-ne 0){throw 'NtCancelIoFileEx XP subsystem retarget failed'}
$headers=(& dumpbin.exe /nologo /headers $exe 2>&1|Out-String)
$headers|Set-Content -Encoding utf8 diagnostics\ntcancel-headers.txt
if($headers-notmatch'(?im)^\s*14C machine \(x86\)'){throw 'NtCancelIoFileEx executable is not x86'}
$subsystem=@($headers-split "`r?`n"|Where-Object{$_-match'(?i)subsystem version'}|Select-Object -First 1)
if(-not$subsystem-or$subsystem[0]-notmatch'^\s*([0-9]+)\.([0-9]+)\s+subsystem version'){throw 'Cannot parse NtCancelIoFileEx subsystem'}
if([version]("$([int]$matches[1]).$([int]$matches[2])")-gt[version]'5.1'){throw 'NtCancelIoFileEx subsystem exceeds XP'}
$mapText=Get-Content $map -Raw;if($mapText.IndexOf('YY_Thunks_NtCancelIoFileEx',[System.StringComparison]::Ordinal)-lt 0){throw 'NtCancelIoFileEx map did not select YY thunk'}
$imports=(& dumpbin.exe /nologo /imports $exe 2>&1|Out-String);$imports|Set-Content -Encoding utf8 diagnostics\ntcancel-imports.txt
$importLines=@($imports -split "`r?`n")
$importedNames=@($importLines|ForEach-Object{
  if($_ -match '^\s*[0-9A-F]+\s+([A-Za-z_?][A-Za-z0-9_@$?.]+)\s*$'){$matches[1]}
})
$importedDlls=@($importLines|ForEach-Object{
  if($_ -match '^\s*([A-Za-z0-9_.-]+\.dll)\s*$'){$matches[1]}
})
if(-not$importedNames.Count-or-not$importedDlls.Count){throw 'NtCancelIoFileEx PE import table parsing failed'}
$importedNames|Set-Content -Encoding ascii diagnostics\ntcancel-imported-symbols.txt
$importedDlls|Set-Content -Encoding ascii diagnostics\ntcancel-imported-dlls.txt
foreach($api in (Get-Content diagnostics\capable-apis.txt)){
  if($importedNames -contains $api){throw "NtCancelIoFileEx retains direct XP KERNEL32 import $api"}
}
foreach($bad in @('NtCancelIoFileEx','ProcessPrng','WindowsCreateString')){
  if($importedNames -contains $bad){throw "NtCancelIoFileEx probe retains forbidden direct import $bad"}
}
foreach($dll in $importedDlls){
  if($dll -match '^(api-ms-win-|ext-ms-)' -or $dll -in @('KERNELBASE.dll','bcrypt.dll')){
    throw "NtCancelIoFileEx probe retains forbidden DLL import $dll"
  }
}
'ntcancel_import_gate=PASS'|Set-Content -Encoding ascii diagnostics\ntcancel-import-gate.txt
& $exe|Tee-Object diagnostics\ntcancel-hosted-run.txt;if($LASTEXITCODE-ne 0){throw "Hosted NtCancelIoFileEx probe failed: $LASTEXITCODE"}
"NTCANCEL_EXE=$exe"|Out-File $env:GITHUB_ENV -Append -Encoding utf8
    }
    default { throw "Unsupported cluster stage: $Stage" }
}
