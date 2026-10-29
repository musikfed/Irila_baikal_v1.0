@echo off
setlocal EnableExtensions DisableDelayedExpansion
REM IRINA GUI single-file launcher v4. Offline. No admin. No download/update/write.
REM Windows 11: double click. Powershell gets UTF-8 code from this SAME file.
set "IRINA_LAUNCHER=%~f0"
set "IRINA_MODE=%~1"
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $p=$env:IRINA_LAUNCHER; $all=[System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8); $tag='### IRINA_PS_START ###'; $at=$all.LastIndexOf($tag); if ($at -lt 0) { throw 'Missing script marker' }; $code=$all.Substring($at+$tag.Length); $block=[ScriptBlock]::Create($code); & $block -SelfTest:($env:IRINA_MODE -eq '--self-test')"
set "IRINA_EXIT=%errorlevel%"
if /I "%~1"=="--self-test" exit /b %IRINA_EXIT%
if not "%IRINA_EXIT%"=="0" (
  echo.
  echo IRINA: Windows blocked or failed to launch the GUI.
  echo No image or disk was changed. Save the error above.
  pause
)
exit /b %IRINA_EXIT%
### IRINA_PS_START ###
param([switch]$SelfTest)

# ALL GUI code is packaged in this CMD file; it is explicitly decoded as
# UTF-8 by Windows PowerShell 5.1, regardless of the active console codepage.
if ($SelfTest) {
    Write-Host 'IRINA GUI v4: UTF8/Powershell 5.1 self-test passed'
    return
}

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$folder = 'F:\irinabaikal'
$image = Join-Path $folder 'irina_baikal_1.0_installed_secureboot.img'
$manifest = "$image.sha256"
$verified = $false

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Ирина Байкал - Windows / внешний USB SSD'
$form.Width = 770
$form.Height = 475
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Ирина Байкал 1.0 - подготовка USB SSD'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20, 18)
$form.Controls.Add($title)

$helpText = New-Object System.Windows.Forms.Label
$helpText.Text = 'Проверка только для чтения. Без администратора. Форматирование и запись выполняются отдельно в Rufus.'
$helpText.Location = New-Object System.Drawing.Point(24, 75)
$helpText.Size = New-Object System.Drawing.Size(705, 55)
$form.Controls.Add($helpText)

$check = New-Object System.Windows.Forms.Button
$check.Text = '1. Проверить IMG и USB SSD'
$check.Location = New-Object System.Drawing.Point(24, 145)
$check.Size = New-Object System.Drawing.Size(222, 42)
$form.Controls.Add($check)

$rufusButton = New-Object System.Windows.Forms.Button
$rufusButton.Text = '2. Открыть Rufus'
$rufusButton.Location = New-Object System.Drawing.Point(261, 145)
$rufusButton.Size = New-Object System.Drawing.Size(210, 42)
$rufusButton.Enabled = $false
$form.Controls.Add($rufusButton)

$github = New-Object System.Windows.Forms.Button
$github.Text = 'Сборки GitHub'
$github.Location = New-Object System.Drawing.Point(486, 145)
$github.Size = New-Object System.Drawing.Size(240, 42)
$form.Controls.Add($github)

$output = New-Object System.Windows.Forms.TextBox
$output.Multiline = $true
$output.ReadOnly = $true
$output.ScrollBars = 'Vertical'
$output.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$output.Location = New-Object System.Drawing.Point(24, 209)
$output.Size = New-Object System.Drawing.Size(701, 177)
$output.Text = 'Проверьте подключение Realtek RTL9210B-CG, затем нажмите первую кнопку.'
$form.Controls.Add($output)

$check.Add_Click({
    $script:verified = $false
    $rufusButton.Enabled = $false
    try {
        if (!(Test-Path -LiteralPath $image -PathType Leaf)) {
            throw "Не найден IMG: $image"
        }
        if (!(Test-Path -LiteralPath $manifest -PathType Leaf)) {
            throw "Не найден контрольный SHA256: $manifest"
        }
        $line = [System.IO.File]::ReadAllText($manifest, [System.Text.Encoding]::UTF8).Trim()
        $found = [regex]::Match(
            $line,
            '^(?<hash>[a-fA-F0-9]{64})\s+\*?irina_baikal_1\.0_installed_secureboot\.img$'
        )
        if (!$found.Success) {
            throw 'Неверный формат SHA256 или имя файла в манифесте.'
        }

        $output.Text = 'Вычисляю SHA-256 образа (несколько ГиБ).'
        [System.Windows.Forms.Application]::DoEvents()
        $actual = (Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash
        if ($actual -ine $found.Groups['hash'].Value) {
            throw 'Контрольная сумма не совпала. Запись образа запрещена.'
        }

        # Win32_DiskDrive is readable by a standard Windows user. We never
        # use diskpart, disk numbers for writing, or disk initialization.
        $disks = @(
            Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop |
                Where-Object {
                    $_.InterfaceType -eq 'USB' -and
                    $_.Model -like '*RTL9210B-CG*' -and
                    [double]$_.Size -ge 230000000000 -and
                    [double]$_.Size -le 275000000000
                }
        )
        if ($disks.Count -ne 1) {
            throw "Не найден ровно один внешний Realtek RTL9210B-CG 256 ГБ. Найдено: $($disks.Count)."
        }
        $disk = $disks[0]
        if (Get-Command Get-Disk -ErrorAction SilentlyContinue) {
            try {
                $info = Get-Disk -Number $disk.Index -ErrorAction Stop
                if ($info.IsBoot -or $info.IsSystem -or $info.BusType -ne 'USB') {
                    throw 'Это системный или не-USB диск; запись не разрешается.'
                }
            } catch [Microsoft.PowerShell.Commands.WriteErrorException] {
                throw
            } catch {
                # WMI identification is sufficient for a read-only helper;
                # Rufus still requires explicit device selection/confirmation.
                if ($_.Exception.Message -like '*системный*') { throw }
            }
        }
        $output.Lines = @(
            'SHA-256: OK. Образ целый.',
            "USB SSD: Disk $($disk.Index); $($disk.Model)",
            "Размер: $([math]::Round([double]$disk.Size / 1GB, 2)) GiB; интерфейс USB.",
            "Файл: $image",
            '',
            'Это НЕ запись. Проверьте модель SSD ещё раз в Rufus перед START.'
        )
        $script:verified = $true
        $rufusButton.Enabled = $true
    } catch {
        $output.Text = "ПРОВЕРКА НЕ ПРОЙДЕНА: $($_.Exception.Message)"
    }
})

$rufusButton.Add_Click({
    if (!$script:verified) { return }
    $msg = 'Rufus полностью сотрёт выбранный диск. Выберите ТОЛЬКО внешний Realtek RTL9210B-CG 256 ГБ. Внутренние диски Windows, D: и F: запрещены. Открыть Rufus?'
    $answer = [System.Windows.Forms.MessageBox]::Show(
        $msg, 'Подтверждение перед Rufus',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $candidates = @(
        (Join-Path $env:USERPROFILE 'Downloads\rufus-4.15.exe'),
        (Join-Path $env:USERPROFILE 'Downloads\rufus-4.15p.exe'),
        (Join-Path $folder 'rufus-4.15.exe'),
        (Join-Path $folder 'rufus-4.15p.exe')
    )
    $exe = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (!$exe) {
        $picker = New-Object System.Windows.Forms.OpenFileDialog
        $picker.Title = 'Выберите уже скачанный Rufus EXE'
        $picker.Filter = 'Rufus (*.exe)|*.exe'
        $picker.InitialDirectory = (Join-Path $env:USERPROFILE 'Downloads')
        if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $exe = $picker.FileName
    }
    try {
        Start-Process -FilePath $exe -ErrorAction Stop
        Start-Process -FilePath 'explorer.exe' -ArgumentList $folder
    } catch {
        $output.Text = "Rufus не запустился: $($_.Exception.Message)"
    }
})

$github.Add_Click({
    Start-Process 'https://github.com/musikfed/Irila_baikal_v1.0/actions/workflows/build-installed-secureboot-img.yml'
})

[void]$form.ShowDialog()
