# Сборка Irina Baikal 1.0: SquashFS + RAM OverlayFS

**Основной путь по ТЗ, пока экспериментальный.** Образ ещё не собирался в окружении Acer. Для проверки используем настоящий Acer через F12 без обязательной тестовой VM.

## Схема

Windows 11 Pro на внутреннем SSD НЕ трогаем. Изолированная Ubuntu 24.04 rootfs создаётся из официальных пакетов в WSL2 (или Ubuntu Live-USB), затем упаковывается в SquashFS. Скрипт запекания создаёт новый файл образа GPT: EFI/FAT32 512 MiB, ext4 IRINA_LIVE, каталог /casper/filesystem.squashfs, ядро и initramfs. GRUB загружает casper, который создаёт временный OverlayFS в RAM, без сохранения записей.

Ограничение готового IMG по умолчанию 5 ГиБ. Профиль --full и Qwen 8B могут превысить бюджет, тогда сборка честно прервётся. Начинать рекомендуется с --core. На этой стадии вместо Rust используется неподписанный GRUB. Подпись, Rust UEFI, постоянный /home и готовая модель Qwen ещё требуют отдельного этапа.

## Вариант А: основной, уже установленная Ubuntu 24.04 в WSL2

**Для Acer WSL2 уже установлена, Ubuntu-24.04 запускается, интернет работает. Не выполнять wsl --install, не создавать IrinaBuilder и не устанавливать отдельную VM.**

Общий порядок: скачать исправленный PowerShell-сценарий v2.1 в F:\irinabaikal; выполнить безопасную проверку -CheckOnly; только после PASS запустить сборку core. **Актуальная подробная инструкция: [BUILD_WSL_F_DRIVE.md](BUILD_WSL_F_DRIVE.md).**

Из PowerShell Windows 11 (можно из C:\WINDOWS\system32):

~~~powershell
Invoke-WebRequest "https://raw.githubusercontent.com/musikfed/Irila_baikal_v1.0/main/windows/Build-IrinaViaWSL-v2.ps1" -OutFile "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1"

Select-String -Path "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1" -Pattern "IRINA WSL BUILDER v2.1", "--exec /bin/bash"
Get-Content "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1" -Distro Ubuntu-24.04 -CheckOnly
~~~

Должно появиться:

~~~text
IRINA WSL BUILDER v2.1 ...
PASS: Ubuntu 24.04 + WSL2 + Linux ext4 staging + F: output
CHECK-ONLY PASS. No packages were installed and no IMG was created.
~~~

После этого:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1" -Distro Ubuntu-24.04 -Profile core
~~~

При запросе ввести **BUILD-IRINA**. Результат после полного успеха:

~~~text
F:\irinabaikal\irina_baikal_1.0.img
F:\irinabaikal\irina_baikal_1.0.img.sha256
~~~

**Причина изменения:** старый windows/Build-IrinaViaWSL.ps1 выдавал «Ubuntu: -c: line 3: conditional binary operator expected» из-за PowerShell-передачи Bash-кода. **Не использовать старый файл даже если он присутствует на F:.** Новая v2.1 запускает временные Bash-файлы, сохраняя кавычки.

Промежуточный Linux-корень создаётся в /srv/irina внутри уже установленной Ubuntu (физически на диске с её VHDX), готовые результаты копируются на F:. Видимые внутри WSL ~940 ГБ виртуального свободного места **не равны** реальному свободному месту диска с VHDX. Внешний SSD 256 ГБ на этом этапе не используется. Программа модифицирует установленный в Ubuntu набор *инструментов сборки*, но не должна удалять проекты. Нужна резервная копия важных Linux-файлов. Не запускать сразу несколько сборок.

## Вариант Б: Ubuntu Live USB, без какой-либо виртуализации

Загрузить официальную Ubuntu 24.04 в режиме Try Ubuntu с ДРУГОЙ флешки через F12 (не устанавливать на внутренний SSD). Нужен отдельный Linux-носитель со свободным местом под сборку; нельзя строить образ на самом SSD, который затем будет очищен записью. В Ubuntu Live выполнить те же команды после установки зависимостей. Это работа с пакетами Linux, а не перенос Windows в Linux.

## Проверка образа в Windows и запись на SSD

Сборщик v2.1 при успешной сборке автоматически копирует IMG и SHA256 на **F:\irinabaikal**; вручную копировать файлы из \\wsl.localhost не требуется. Проверка на Windows:

~~~powershell
Invoke-WebRequest "https://raw.githubusercontent.com/musikfed/Irila_baikal_v1.0/main/scripts/flash_irina.py" -OutFile "F:\irinabaikal\flash_irina.py"
py -3.13 "F:\irinabaikal\flash_irina.py" --image "F:\irinabaikal\irina_baikal_1.0.img"
~~~

Скрипт только сверяет SHA256 и показывает сведения о дисках для чтения. После успешной проверки Rufus https://rufus.ie/ → выбрать **только отдельный внешний SSD 256 ГБ USB 3.0** (~238,46 ГиБ) → записать IMG как raw/DD, если Rufus это предлагает. Весь выбранный накопитель стирается. Не выбирать внутренний Windows NVMe ~512 ГБ, D: или F:. Номер диска не является надёжным идентификатором — сверять USB, модель, размер и отключение/подключение. Дополнительно форматировать SSD не нужно.

## Первая загрузка

Выключить Acer, выбрать внешний диск через F12. Неподписанный GRUB может не работать при включённом Secure Boot. Прежде чем менять настройку Secure Boot, убедиться, что сохранён ключ восстановления BitLocker/шифрования Windows. На первом запуске проверить Wi-Fi QCA61x4A, Vega 8, Realtek, HD WebCam, звук, Irina Shell, язык и временный RAM-overlay. Если не загружается — фото экрана ошибки для исправления.

Внимание: пользовательские письма, файлы, настройки и модель, сохранённые в RAM-overlay, исчезнут при перезапуске. Для постоянного /home в будущей сборке будет настроен отдельный DATA-раздел. После записи компактного IMG оставшееся пространство 256 ГБ SSD останется неразмеченным.

**Статус:** скрипты подготовки и запекания, затем реальные испытания F12; ни загрузку, ни размер результата на Acer пока нельзя гарантировать.


## Вариант В: только Windows 11 и GitHub Actions, без локальной Ubuntu / WSL

Это удобный вариант для сборки файла образа без установки Linux на Acer. Используется временный GitHub-hosted Ubuntu runner для **сборки**, а не для обязательного виртуального тестирования.

1. Открыть вкладку **Actions** репозитория.
2. Найти workflow **Build Irina Baikal read-only IMG**.
3. Нажать **Run workflow**, оставить профиль **core** и максимальный размер **5120 MiB**.
4. Если сборка завершилась успешно, скачать Artifact **irina-baikal-1.0-readonly-img**.
5. Распаковать полученный ZIP в Windows — нужны оба файла IMG и SHA256.
6. Проверить хеш скриптом **scripts/flash_irina.py**, затем выбрать внешний SSD 256 ГБ вручную в Rufus.

GitHub ограничивает дисковое пространство runner и хранилище Artifact: большая сборка может не завершиться. Успех проверок синтаксиса НЕ равен готовому образу. После реального запуска Acer через F12 проверить устройства. Если сборка в GitHub не удастся, использовать вариант WSL2 или Ubuntu Live-USB.
