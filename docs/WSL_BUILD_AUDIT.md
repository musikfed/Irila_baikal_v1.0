# Аудит сборки Irina Baikal через WSL2 (29 октября 2026)

## Вывод

**PowerShell Windows запускать от имени администратора НЕ нужно.** Ubuntu-24.04 WSL2 уже зарегистрирована. Команда wsl.exe --user root запускает необходимые Linux-операции от Linux root без повышения прав Windows. Запускать обычный PowerShell от того же Windows-пользователя, которому принадлежит Ubuntu.

Используйте [исправленный сценарий v2.2](../windows/Build-IrinaViaWSL-v2.ps1). Старый Build-IrinaViaWSL.ps1 давал ошибку Bash условного оператора из-за bash -lc. Новый передаёт временные Linux Bash-сценарии как UTF-8 LF-файлы и запускает их через wsl --exec /bin/bash.

## Реально проверено в GitHub

- Синтаксис PowerShell, Bash и Python (GitHub Actions).
- Синтаксис Bash-сценариев, встроенных в Windows PowerShell v2.
- Безопасная опция -CheckOnly присутствует, не запускает apt или сборку.
- [Автоматический тест SHA256](../tests/test_readonly_pipeline.py) использует настоящую часть кода генерации контрольной суммы и специально повреждает копию IMG: проверка обнаруживает повреждение.
- Исправлены переносимость SHA256 (используется только имя файла, а не абсолютный /srv/irina/... путь), обновление GPT/loop-разделов через partx и явно устанавливаемые пакеты udev и mount.

**НЕ проверено:** полная установка пакетов в Ubuntu WSL Acer, доступность loop/GPT на этом WSL, итоговый IMG, загрузка через Acer F12. Успех CI не означает готовый загрузочный образ.

## Проверенное предполагаемое наполнение профиля core

- Ubuntu Noble 24.04, linux-image-generic, casper, SquashFS zstd, RAM overlay при live-загрузке.
- Рабочий стол XFCE, LightDM, NetworkManager, Xorg; локальная Irina Shell HTML/JS.
- Браузер Epiphany, RU/EN locales, PipeWire, базовая поддержка AMD, Wi-Fi, звука, камеры.
- Звуковое приветствие из репозитория и Hrag FastAPI-сервис.

Пакеты LibreOffice, GIMP, Inkscape, Thunderbird, Linphone, игры — профиль full. Модель Qwen 8B, предустановленный Ollama, сохранение данных после перезагрузки, Rust Secure Boot пока не включены. Драйверы и реальное графическое окружение ещё не испытаны на Acer.

## Диски и безопасность

Внешний M.2 SSD 256 GB (~238,46 GiB) пуст — **не используется при сборке**. Внутренний NVMe 512 GB с Windows не форматируется. Папка результата — F:\irinabaikal, проверено около 253 GiB свободного места. Промежуточная Ubuntu rootfs создаётся ВНУТРИ существующей WSL в /srv/irina/rootfs, то есть на физическом диске, где лежит ext4.vhdx (по информации владельца D:). Приведённая WSL виртуальная ёмкость ~940 GB не гарантирует такой же реальной физической ёмкости.

Запуск -Profile core установит дополнительные инструменты сборки в существующей Ubuntu WSL; до этого рекомендуется сделать резервные копии важных Linux-проектов. Другая Ubuntu / IrinaBuilder не требуется.

## Команды Windows PowerShell (обычный пользователь)

1. Скачать актуальную исправленную версию:

    Invoke-WebRequest "https://raw.githubusercontent.com/musikfed/Irila_baikal_v1.0/main/windows/Build-IrinaViaWSL-v2.ps1" -OutFile "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1"

2. Проверить, что скачана v2.2:

    Select-String -Path "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1" -Pattern "IRINA WSL BUILDER v2.2"

3. Проверить PowerShell-скрипт визуально:

    Get-Content "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1"

4. Запустить безопасную проверку без установки пакетов:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1" -Distro Ubuntu-24.04 -CheckOnly

Ожидаемые фразы: PASS: Ubuntu 24.04 + WSL2 + Linux ext4 staging + F: output и CHECK-ONLY PASS.

Для проверки физического места D: только чтение:

    Get-Volume -DriveLetter D | Select DriveLetter,Size,SizeRemaining

Только ПОСЛЕ удачного CheckOnly и сохранения важных Linux-проектов:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1" -Distro Ubuntu-24.04 -Profile core

При запросе ввести BUILD-IRINA. По завершении ожидаются F:\irinabaikal\irina_baikal_1.0.img и F:\irinabaikal\irina_baikal_1.0.img.sha256. Проверить их Windows Python скриптом flash_irina.py перед любыми действиями с Rufus.

Для полной процедуры см. [инструкцию Windows + WSL2](BUILD_WSL_F_DRIVE.md).
