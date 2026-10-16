param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('bundle')]
    [string]$Stage
)

switch ($Stage) {
    'bundle' {
@'
@echo off
echo XP x86 core KERNEL32 cluster runtime probe
xp-core-kernel32-cluster.exe
if errorlevel 1 exit /b %ERRORLEVEL%
echo XP x86 NtCancelIoFileEx YY runtime probe
xp-ntcanceliofileex.exe
set EC=%ERRORLEVEL%
echo DriverExitCode=%EC%
exit /b %EC%
'@|Set-Content -Encoding ascii runtime\run-xp-cluster.cmd
@'
Physical Windows XP SP3 x86 acceptance
=======================================
Candidate evidence: full Firefox run 33479649627 / job 99766203250 / SHA d2f15ee8f0cef8112855c4306014865e422319d3.
Run: run-xp-cluster.cmd
Preserve complete stdout. The bundle now also tests YY-Thunks 1.2.3 NtCancelIoFileEx from a physically narrow ntdll provider.
Hosted Windows execution is not physical-XP proof. This artifact does not choose production remediation.
'@|Set-Content -Encoding ascii runtime\README-XP.txt
Copy-Item diagnostics\yy-capability.tsv runtime\yy-capability.tsv
Copy-Item diagnostics\yy-ntdll-capability.tsv runtime\yy-ntdll-capability.tsv
Get-ChildItem runtime -File|ForEach-Object{$h=Get-FileHash -Algorithm SHA256 $_.FullName;"$($h.Hash.ToLowerInvariant())  $($_.Name)"}|Set-Content -Encoding ascii runtime\SHA256SUMS.txt
Get-FileHash -Algorithm SHA256 $env:SMOKE_EXE|Format-List|Out-String|Set-Content -Encoding utf8 diagnostics\probe-sha256.txt
Get-FileHash -Algorithm SHA256 $env:NTCANCEL_EXE|Format-List|Out-String|Set-Content -Encoding utf8 diagnostics\ntcancel-probe-sha256.txt
    }
    default { throw "Unsupported cluster stage: $Stage" }
}
