# «Ирина Байкал 1.0» — сборка IMG через существующую Ubuntu WSL2 на Windows 11

**Актуальная инструкция для Acer Swift 3 SF314-41, 29.10.2026.** Старая команда с windows/Build-IrinaViaWSL.ps1 выдавала ошибку «Ubuntu: -c: line 3: conditional binary operator expected»: Windows PowerShell некорректно передавал Bash-условия через bash -lc. **Использовать только новый [Build-IrinaViaWSL-v2.ps1](../windows/Build-IrinaViaWSL-v2.ps1), v2.2.** В нём команды исполняются из временного UTF-8 LF-файла по пути /mnt/f, без ошибок кавычек.

## Что уже проверено

- Существующая Ubuntu WSL называется **Ubuntu-24.04**, WSL 2, успешный запуск /bin/true завершился с кодом 0.
- DNS archive.ubuntu.com работает, HTTPS-запрос вернул HTTP 200 OK. Предупреждение WSL об обнаруженном localhost proxy пока не мешало соединению.
- Папка **F:\irinabaikal** существует. На F: свободно ~253 ГиБ.
- На существующей Ubuntu есть другие проекты. **Не устанавливать новую Ubuntu, не экспортировать существующую, не выполнять wsl --unregister и не удалять личные файлы.**
- Отдельный внешний SSD **256 ГБ** (~238,46 ГиБ в Windows) пока пустой. Он **не является диском F:**.

**Примечание о месте:** Ubuntu WSL показывает ~940 ГБ доступного пространства внутри виртуального ext4, но это *не* означает столько же свободного физического места на D:. Промежуточные файлы сборки находятся в /srv/irina в существующей WSL; готовые IMG и SHA256 копируются на F:. Убедитесь, что на реальном диске с WSL достаточно места.

## Нужен ли PowerShell «Запуск от имени администратора»?

**Нет. Запускайте обычный PowerShell под тем же пользователем Windows, у которого зарегистрирована Ubuntu-24.04.** Команда `wsl.exe --user root` даст необходимые root-права **внутри Linux**. Windows-администратор нужен для установки/включения компонентов Windows, но WSL2 уже установлен, и существующая Ubuntu успешно запускается. Из `C:\WINDOWS\system32` команды тоже работают, потому что сценарий использует абсолютные пути F:.

**Аудит кода:** [тесты контрольной суммы и Bash-команд](../tests/test_readonly_pipeline.py) проверяют сохранение кавычек WSL, синтаксис скриптов, относительные пути SHA256, корректную проверку *копии* на F: и отказ при её повреждении. **Скрипт полной сборки образа на Acer ещё не выполнялся.** Проверка `-CheckOnly` гарантирует лишь базовые условия: она не проверяет совместимость реального WSL с loop/GPT, все пакеты или загрузку с SSD.

## 1. Скачать актуальную v2.2 в PowerShell Windows

Эти команды можно выполнять из PS C:\WINDOWS\system32:

~~~powershell
Invoke-WebRequest "https://raw.githubusercontent.com/musikfed/Irila_baikal_v1.0/main/windows/Build-IrinaViaWSL-v2.ps1" -OutFile "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1"
Select-String -Path "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1" -Pattern "IRINA WSL BUILDER v2.2", "--exec /bin/bash"
Get-Content "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1"
~~~

Проверьте содержимое до исполнения. Если строка **IRINA WSL BUILDER v2.2** не найдена, остановитесь. Имя **v2** должно присутствовать *и при скачивании, и при запуске*. Старый файл на F: можно оставить, но его больше не запускать.

## 2. Запустить проверку WSL без установки пакетов

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1" -Distro Ubuntu-24.04 -CheckOnly
~~~

Ожидаемый вывод:

~~~text
IRINA WSL BUILDER v2.2 (file-based Bash runner, 2026-10-29)
PASS: Ubuntu 24.04 + WSL2 + Linux ext4 staging + F: output
CHECK-ONLY PASS. No packages were installed and no IMG was created.
NOTE: This does NOT verify loop/GPT capability, installed packages, full image build or Acer boot.
~~~

Параметр -CheckOnly **не выполняет apt, не создаёт rootfs или IMG и не изменяет физические диски**. Он проверяет версии WSL/Ubuntu, Linux ext4 для промежуточных файлов и доступность F:. Полный тест loop/GPT выполняется уже на следующем этапе только во временном файле.

Если вновь появляется «Ubuntu: -c: line 3» либо старое сообщение «WSL preflight failed; no build started» *без кода*, это **старый файл**, а не неисправность WSL.

## 3. Собрать первую, компактную версию

Только после CHECK-ONLY PASS выполнить:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\irinabaikal\Build-IrinaViaWSL-v2.ps1" -Distro Ubuntu-24.04 -Profile core
~~~

При приглашении ввести **BUILD-IRINA** и нажать Enter.

Сценарий устанавливает в существующую WSL системные **инструменты сборки**, получает код собственного GitHub, проверяет GPT/loop на *временном файле*, создаёт отдельный Ubuntu 24.04 rootfs в /srv/irina/rootfs, упаковывает SquashFS и создаёт GPT + UEFI raw IMG с контрольной суммой. **Не форматирует** никакой физический SSD.

Он установит новые Linux-пакеты в существующую Ubuntu, но не должен удалять проекты. Перед вмешательством в рабочую Linux-систему стоит сохранить резервные копии важных файлов. Не запускайте два сборщика одновременно.

Если процесс прервался, **не повторяйте запуск наугад**: сборщик защищён от перезаписи уже созданного /srv/irina/rootfs. Сохраните текст ошибки. Нельзя удалять другие проекты или очищать всю WSL ради повторения.

## 4. Проверить итоговые файлы

Они появляются **только при успешном завершении**:

~~~text
F:\irinabaikal\irina_baikal_1.0.img
F:\irinabaikal\irina_baikal_1.0.img.sha256
~~~

WSL скрипт сравнивает SHA256 образа до и после копирования. Дополнительно Windows-проверка, **только чтение**:

~~~powershell
Invoke-WebRequest "https://raw.githubusercontent.com/musikfed/Irila_baikal_v1.0/main/scripts/flash_irina.py" -OutFile "F:\irinabaikal\flash_irina.py"
py -3.13 "F:\irinabaikal\flash_irina.py" --image "F:\irinabaikal\irina_baikal_1.0.img"
~~~

Этот Python-скрипт только проверяет SHA и отображает сведения о дисках. Запись raw IMG на внешний накопитель им **не производится**.

## 5. Запись на внешний SSD и первое включение Acer (отдельный этап!)

После готового IMG и корректного SHA256 в Rufus выбрать **только внешний USB M.2 SSD 256 ГБ**, который отображался как ~238,46 ГиБ неразмеченного места. **Не выбирать** NVMe ~512 ГБ с Windows, раздел F: или D:. Проверить модель, интерфейс USB и наличие/отсутствие диска при отсоединении и подключении. Номер диска может меняться. Rufus выполняет стирание *только вручную выбранного накопителя*; заранее разбивать диск на разделы не требуется.

После записи: выключить Acer, включить, выбрать внешний накопитель через **F12**. В текущем IMG неподписанный GRUB (не готовый Rust Secure Boot), поэтому при Secure Boot возможна ошибка. **Прежде чем менять UEFI/Secure Boot, заранее сохранить ключ восстановления BitLocker Windows.**

**Статус:** полная сборка на Acer и первая физическая загрузка пока **не подтверждены**. Синтаксические проверки GitHub Actions — не доказательство готовности IMG.

## 6. Ограничения первой сборки

Профиль **core**: Ubuntu 24.04, XFCE, Irina Shell, базовые драйверы, браузер, Hrag, SquashFS и временный RAM OverlayFS. Полный профиль **full** включает LibreOffice, GIMP, Inkscape, Thunderbird, Linphone и игры, но может превысить лимит 5 ГиБ — пробовать только после core. Qwen 8B, сохранение данных на отдельном DATA и подписанный Rust EFI загрузчик **ещё не готовы**. Данные в RAM-overlay пропадают после перезагрузки.

При проблемах с loop/GPT не подключать физические Windows-диски к WSL; альтернативы: [GitHub Actions сборка IMG](../.github/workflows/build-readonly-img.yml) или Ubuntu Live USB. Для восстановления WSL см. [WSL_RECOVERY.md](WSL_RECOVERY.md). **Не выполнять wsl --unregister.**
