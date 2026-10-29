# Основная сборка «Ирина Байкал 1.0» — GitHub Actions CI

**Дата: 29 октября 2026.** GitHub — источник проекта и основной способ собрать IMG в облаке. Не нужны локальный WSL, PowerShell администратора или доступ к заблокированному D:\WSL\Ubuntu-24.04\ext4.vhdx.

Репозиторий: https://github.com/musikfed/Irila_baikal_v1.0
Workflow: [Build Irina Baikal read-only IMG](../.github/workflows/build-readonly-img.yml).

## 1. Как запускается реальная сборка

Workflow запускается автоматически на main после изменения кода сборки или самого workflow. Он также поддерживает **ручной запуск**:

1. GitHub → репозиторий → Actions.
2. Выбрать **Build Irina Baikal read-only IMG**.
3. Нажать **Run workflow** → branch main.
4. Profile **core** и max_mib **5120** → Run workflow.

При автоматическом запуске используются те же core и 5120. Если задача уже выполняется, запускать вторую вручную не нужно.

Pipeline: установка Ubuntu инструментов → loop/GPT-тест временного файла → debootstrap Ubuntu 24.04 Noble → ядро, casper, XFCE и Irina Shell → SquashFS zstd → GPT/FAT32 EFI + ext4 live IMG → SHA256 → Artifacts.

Успешный CI-тест синтаксиса **не равен** готовому загрузочному IMG. Должен завершиться с Success именно workflow **Build Irina Baikal read-only IMG**, и появиться Artifact.

## 2. Скачать результат

Открыть успешный запуск workflow, прокрутить до Artifacts, скачать **irina-baikal-1.0-readonly-img**. Распаковать ZIP в папку **F:\irinabaikal**:

- F:\irinabaikal\irina_baikal_1.0.img
- F:\irinabaikal\irina_baikal_1.0.img.sha256

Срок хранения артефакта ограничен текущей настройкой workflow (изначально один день). Скачайте сразу после успеха. Если запуская сборку видите Failure — готового IMG нет.

Проверка только чтение, в Windows PowerShell:

~~~powershell
Invoke-WebRequest "https://raw.githubusercontent.com/musikfed/Irila_baikal_v1.0/main/scripts/flash_irina.py" -OutFile "F:\irinabaikal\flash_irina.py"
py -3.13 "F:\irinabaikal\flash_irina.py" --image "F:\irinabaikal\irina_baikal_1.0.img"
~~~

## 3. Внешний SSD 256 ГБ

**Не выполнять никаких операций над физическим SSD до полной сборки и успешной SHA256-проверки.** Затем в Rufus вручную выбрать только **внешний USB M.2 SSD 256 GB** (~238,46 GiB в Windows). Не выбирать Windows NVMe 512 GB, D: или F:. Проверить модель, USB, объём и изменение списка дисков при отключении/подключении. Rufus raw/DD запись очищает выбранный SSD. Первое включение Acer через F12.

Подписанного EFI загрузчика ещё нет, поэтому Secure Boot может блокировать старт. Сохранить BitLocker recovery key перед любыми изменениями UEFI/Secure Boot.

## 4. Неисправная локальная Ubuntu WSL на D:

Сейчас WSL Ubuntu-24.04 выдаёт MountDisk/HCS/E_ACCESSDENIED для D:\WSL\Ubuntu-24.04\ext4.vhdx. **GitHub CI НЕ зависит от локальной Ubuntu, поэтому удаление/ремонт WSL для сборки не требуется.**

Если все нужные проекты действительно сохранены в GitHub и владелец согласен потерять ВСЕ локальные файлы Ubuntu (включая несохранённые в GitHub, gitignore и SSH-ключи), её можно полностью удалить. Операция необратима и не затрагивает GitHub-репозитории.

В PowerShell от того же пользователя Windows:

~~~powershell
wsl --list --verbose
wsl --shutdown
wsl --unregister Ubuntu-24.04
wsl --list --verbose
~~~

**Внимание:** unregister удаляет зарегистрированный Linux-дистрибутив и его локальные файлы. Не выполнять отдельного удаления папки D:\WSL с помощью Remove-Item, не очищать раздел D:, не форматировать F: и не использовать diskpart clean. При E_ACCESSDENIED остановитесь, не обходите ошибку принудительным удалением ext4.vhdx.

После удаления повторная установка Ubuntu потребуется только при возвращении к локальной разработке. Для CI можно оставить Windows вообще без WSL.

## 5. Ограничения

Core пока без полноценного офиса и модели Qwen 8B. Full добавляет LibreOffice, GIMP, Inkscape, Thunderbird, Linphone, игры и может потребовать образ 8192 MiB. Live-документы в RAM overlay исчезнут при перезагрузке; отдельный persistent DATA и подписанный Rust UEFI загрузчик ещё не реализованы.

Дополнительно: [запасной маршрут WSL2](BUILD_WSL_F_DRIVE.md), [аудит сборки](WSL_BUILD_AUDIT.md).
