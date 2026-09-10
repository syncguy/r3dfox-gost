$ErrorActionPreference = 'Stop'

$cpu = @(Get-CimInstance Win32_Processor)
$system = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$active = @(Get-CimInstance Win32_PageFileUsage)
$activeMB = ($active | Measure-Object -Property AllocatedBaseSize -Sum).Sum
if ($null -eq $activeMB) {
  $activeMB = 0
}

[pscustomobject]@{
  CpuName           = ($cpu.Name -join '; ')
  CpuSockets        = $cpu.Count
  CpuCores          = ($cpu | Measure-Object NumberOfCores -Sum).Sum
  LogicalProcessors = ($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum
  SystemLogicalCPUs = $system.NumberOfLogicalProcessors
  TotalPhysicalGB   = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
  FreePhysicalGB    = [math]::Round($os.FreePhysicalMemorySize / 1MB, 2)
  TotalVirtualGB    = [math]::Round($os.TotalVirtualMemorySize / 1MB, 2)
  FreeVirtualGB     = [math]::Round($os.FreeVirtualMemory / 1MB, 2)
} | Format-List

$active | Select-Object Name,AllocatedBaseSize,CurrentUsage,PeakUsage | Format-Table -AutoSize
if ($activeMB -lt 20480) {
  throw "Build blocked: active pagefile is only $activeMB MB."
}
