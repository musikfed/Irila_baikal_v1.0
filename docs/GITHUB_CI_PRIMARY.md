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

**Технический статус облачного IMG:** один запуск уже успешно выполнил debootstrap Ubuntu, сжатие SquashFS и GPT/UEFI IMG (3,0 GiB), но завершился с ошибкой публикации артефакта (Permission denied при mv из /srv/irina). Workflow исправлен: теперь он копирует IMG и сверяет SHA256 копии перед upload-artifact. До Success нового workflow и появления Artifact скачиваемого IMG ещё нет.

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

## 4. Локальная WSL не установлена — это нормально для CI

**Текущее состояние Windows WSL:** команда wsl --list --verbose сообщает, что зарегистрированных дистрибутивов нет. Поэтому wsl --unregister Ubuntu-24.04 возвращает WSL_E_DISTRO_NOT_FOUND; это ожидаемо, повторять команду не нужно. **GitHub CI не зависит от WSL на Acer.** Даже если D:\WSL\Ubuntu-24.04\ext4.vhdx ещё существует как незарегистрированный файл, это не мешает облачной сборке.

**Сейчас удалять через WSL нечего:** Ubuntu уже отсутствует в списке. Не выполнять wsl --unregister повторно. При желании только проверить, остался ли старый VHDX на D:, в PowerShell выполнить Test-Path "D:\WSL\Ubuntu-24.04\ext4.vhdx". Это не удаляет файл. Если VHDX существует, его очистка — отдельная операция, не нужна для GitHub CI; без проверки других хранящихся на D: данных не удалять всё содержимое D:\WSL.

Установка Ubuntu WSL потребуется только если позже решите вернуться к локальной разработке. Для CI можно оставить Windows вообще без WSL.

## 5. Ограничения

Core пока без полноценного офиса и модели Qwen 8B. Full добавляет LibreOffice, GIMP, Inkscape, Thunderbird, Linphone, игры и может потребовать образ 8192 MiB. Live-документы в RAM overlay исчезнут при перезагрузке; отдельный persistent DATA и подписанный Rust UEFI загрузчик ещё не реализованы.

Дополнительно: [запасной маршрут WSL2](BUILD_WSL_F_DRIVE.md), [аудит сборки](WSL_BUILD_AUDIT.md).
