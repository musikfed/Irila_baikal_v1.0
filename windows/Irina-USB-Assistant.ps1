# IRINA BAIKAL Windows USB assistant. Read-only checks; Rufus does the writing.
param([string]$Folder = 'F:\irinabaikal')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Ирина Байкал — подготовка внешнего SSD'
$form.Width = 760
$form.Height = 430
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$heading = New-Object System.Windows.Forms.Label
$heading.Text = 'Ирина Байкал — Windows → USB SSD → Acer'
$heading.Font = New-Object System.Drawing.Font('Segoe UI',16,[System.Drawing.FontStyle]::Bold)
$heading.AutoSize = $true; $heading.Left=22; $heading.Top=22
$form.Controls.Add($heading)
$hint=New-Object System.Windows.Forms.Label
$hint.Text='Эта программа НЕ форматирует и НЕ записывает диски. Rufus работает отдельно.'
$hint.Left=24; $hint.Top=70; $hint.Width=700; $hint.Height=45
$form.Controls.Add($hint)
$path=New-Object System.Windows.Forms.Label
$path.Text="Папка результатов: $Folder"
$path.Left=24; $path.Top=117; $path.Width=700; $path.Height=25
$form.Controls.Add($path)
$status=New-Object System.Windows.Forms.TextBox
$status.Multiline=$true; $status.ScrollBars='Vertical'; $status.ReadOnly=$true
$status.Left=24; $status.Top=218; $status.Width=695; $status.Height=133
$status.Font = New-Object System.Drawing.Font('Consolas',10)
$form.Controls.Add($status)
$check=New-Object System.Windows.Forms.Button
$check.Text='1. Проверить IMG и USB SSD'
$check.Left=24; $check.Top=160; $check.Width=222; $check.Height=40
$form.Controls.Add($check)
$open=New-Object System.Windows.Forms.Button
$open.Text='2. Открыть Rufus'
$open.Left=263; $open.Top=160; $open.Width=200; $open.Height=40
$open.Enabled=$false
$form.Controls.Add($open)
$github=New-Object System.Windows.Forms.Button
$github.Text='Открыть сборку GitHub'
$github.Left=481; $github.Top=160; $github.Width=238; $github.Height=40
$form.Controls.Add($github)
$script:verified=$false
$check.Add_Click({
  $script:verified=$false; $open.Enabled=$false
  $img=Join-Path $Folder 'irina_baikal_1.0_installed_secureboot.img'
  $sha="$img.sha256"
  if (!(Test-Path -LiteralPath $img -PathType Leaf) -or !(Test-Path -LiteralPath $sha -PathType Leaf)) {
    $status.Lines=@("Образ установленной версии пока не найден.",
      "После успешного CI скачайте и распакуйте артефакт в $Folder")
    return
  }
  try {
    $line=(Get-Content -LiteralPath $sha -Raw).Trim()
    if ($line -notmatch '^(?<Hash>[a-fA-F0-9]{64})\s+\*?irina_baikal_1\.0_installed_secureboot\.img$') {
      throw 'Неверный формат SHA256 или имя образа'
    }
    $expected=$Matches.Hash
    $digest=(Get-FileHash -LiteralPath $img -Algorithm SHA256).Hash
    if ($digest -ine $expected) { throw 'SHA-256 НЕ совпал — записывать запрещено' }
    $devices=@(Get-Disk -ErrorAction Stop | Where-Object {
      $_.BusType -eq 'USB' -and $_.Size -ge 230000000000 -and $_.Size -le 275000000000 -and
      !$_.IsBoot -and !$_.IsSystem
    })
    if ($devices.Count -ne 1) { throw "Нужен ровно один USB SSD около 256 GB; найдено: $($devices.Count)." }
    $disk=$devices[0]
    $status.Lines=@("SHA256: OK",
       "Внешний SSD: Disk $($disk.Number) | $($disk.FriendlyName) | $([math]::Round($disk.Size / 1GB,2)) GiB",
       "BusType USB; Boot/System False",
       "IMG: $img",
       "В Rufus проверьте устройство ДО нажатия START.")
    $script:verified=$true
    $open.Enabled=$true
  } catch {
    $status.Lines=@("ПРОВЕРКА НЕ ПРОШЛА: $($_.Exception.Message)",
     "Никаких записей на диски не было.")
  }
})
$open.Add_Click({
    if (!$script:verified) { return }
    $answer=[System.Windows.Forms.MessageBox]::Show(
       'Сейчас откроется Rufus. В нём выберите Realtek RTL9210B-CG ~256 GB и правильный IMG. Запись сотрёт SSD. Внутренние NVMe, D: и F: не выбирать. Продолжить?',
       'Проверка целевого диска',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $candidates=@(
       (Join-Path $env:USERPROFILE 'Downloads\rufus-4.15.exe'),
       (Join-Path $env:USERPROFILE 'Downloads\rufus-4.15p.exe'),
       (Join-Path $Folder 'rufus-4.15.exe'),
       (Join-Path $Folder 'rufus-4.15p.exe')
    )
    $rufus=$candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ($rufus) { Start-Process -FilePath $rufus }
    else { Start-Process 'https://rufus.ie/' }
    Start-Process explorer.exe -ArgumentList $Folder
})
$github.Add_Click({ Start-Process 'https://github.com/musikfed/Irila_baikal_v1.0/actions/workflows/build-installed-secureboot-img.yml' })
$status.Lines=@("Скачайте новый IMG из успешного CI.",
 "Предыдущие образы на F: программа не изменяет.")
[void]$form.ShowDialog()
