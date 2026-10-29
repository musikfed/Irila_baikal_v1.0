# Read-only: identifies SSD candidates. NEVER erases, formats or writes to any disk.
$ErrorActionPreference = 'Stop'
Write-Host 'IRINA BAIKAL - READ ONLY DISK INSPECTOR' -ForegroundColor Cyan
Get-Disk | ForEach-Object {
    [PSCustomObject]@{
      Number = $_.Number
      Model = $_.FriendlyName
      Bus = $_.BusType
      SizeGB = [math]::Round($_.Size / 1GB, 1)
      Boot = $_.IsBoot
      System = $_.IsSystem
      PartitionStyle = $_.PartitionStyle
    }
} | Format-Table -AutoSize
Write-Host 'Do NOT flash internal disk. External M.2 256GB must be independently verified by model, USB bus and unplug test.' -ForegroundColor Yellow
Write-Host 'This program performs no disk writes.' -ForegroundColor Green
