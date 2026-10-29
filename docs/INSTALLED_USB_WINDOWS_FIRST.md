# Ирина Байкал: Windows-first установленная система на USB SSD

**Архитектура владельца:** Windows — графическая управляющая среда, GitHub Actions собирает целиком готовый диск. Нет ручного разбиения разделов, форматирования ext4, LiveCD-installer, diskpart или Linux CLI.

## Схема

- GitHub CI: подготовить Ubuntu 24.04 с уже известным Acer Swift 3 SF314-41, AMD Vega, QCA61x4A, PipeWire, XFCE, Irina Shell и Hrag.
- GitHub CI: создать новый самостоятельный GPT IMG с 512 MiB FAT32 EFI и записываемым ext4 IRINA_ROOT, с Ubuntu Microsoft 2011/2023 dualsigned shim, Canonical-signed GRUB и signed kernel. Результат — обычный файл, без доступа CI к физическим дискам.
- Windows: скачать готовый artifact, проверить SHA и внешний Realtek RTL9210B-CG 256GB в графическом помощнике; нажать «Открыть Rufus»; вручную проверить выбор физического USB SSD в Rufus и подтвердить стирание.
- Acer: один раз выбрать внешний USB SSD через F12 (прошивку и настройки Windows не менять). Secure Boot остаётся Enabled; BitLocker остаётся включённым.
- При загрузке: Linux запускается непосредственно с записываемого ext4. **Нет Casper, нет SquashFS и нет RAM OverlayFS.** Файлы и настройки сохраняются.
- Первый запуск: systemd-служба пытается расширить IRINA_ROOT до всей ёмкости USB SSD 256GB. Выполняет операцию только после проверок: собственный / раздел с меткой IRINA_ROOT, номер раздела 2, USB-шина, GPT и ёмкость 230–275 миллиардов байт. Если проверки не проходят — никаких действий с разделами.
- После подключения Wi-Fi: systemd автоматически устанавливает LibreOffice Writer/Calc/Impress, GIMP, Inkscape, Thunderbird из Ubuntu. Повторяет попытку, когда сеть недоступна. Статус виден в графическом окне Irina Setup на русском; терминал не требуется.

## Все версии сохраняются

1. Первый IMG (без подписи): irina_baikal_1.0.img
2. Live Secure Boot: irina_baikal_1.0_secureboot.img
3. Live Secure Boot R2 Casper fix: irina_baikal_1.0_r2_secureboot.img
4. **Новый Installed Secure Boot R1: irina_baikal_1.0_installed_secureboot.img**

Новый GitHub Actions workflow: [Build Irina Baikal Installed USB Secure Boot](../.github/workflows/build-installed-secureboot-img.yml). Новый артефакт: **irina-baikal-1.0-installed-secureboot-img**. Артефакт появляется только после статуса Success. Размер raw-образа около 6–8 GiB, сжатый download может быть существенно меньше.

## Порядок действий без командной строки

1. Открыть новый workflow в GitHub Actions. Он запускается на push сборочных файлов либо вручную через Run workflow → main → core → 8192 MiB.
2. После Success скачать Artifact irina-baikal-1.0-installed-secureboot-img и распаковать оба файла IMG + IMG.sha256 в F:\irinabaikal.
3. Скачать в одну папку два файла из репозитория: [Irina-USB-Assistant.ps1](../windows/Irina-USB-Assistant.ps1) и [Start-Irina-USB-Assistant.cmd](../windows/Start-Irina-USB-Assistant.cmd). Двойной щелчок по CMD откроет графический помощник в Windows, без Windows Administrator.
4. Нажать «Проверить IMG и USB SSD». Программа ничего не записывает и проверяет SHA256 и подключение ровно одного подходящего USB-диска 256GB. Затем «Открыть Rufus».
5. **Rufus сам записывает готовую GPT-разметку, EFI-загрузчик и ext4.** Выбирай только Realtek RTL9210B-CG USB 238,47 GiB. Не выбирать внутренний Windows NVMe HFM512GDJTNG-8310A 476,94 GiB и SATA AMD R5SL120G 111,79 GiB. Запись полностью сотрёт выбранный SSD. Программа-помощник диск не форматирует.
6. Rufus READY → перезагрузка Acer → F12 → внешний USB SSD → XFCE + Irina Shell → подключение Wi-Fi через значок сети → графический статус автоматической установки программ. Старые IMG на F: останутся без изменений.

## Защита и ограничения

- Расширение выполняется только на USB-диске, с которого действительно запущена установленная ОС. Не создаём разделы на D:, F:, C: и не трогаем Windows, TPM, BitLocker, MBR/Legacy BIOS.
- При ошибке расширения служба записывает лог, не обращаясь к другим дискам. Установка крупных приложений может быть отложена до появления свободного места.
- Драйверы для известных AMD/QCA/камеры/звука уже включены, Linux загружает их автоматически. Но реальная работа Wi-Fi/GPU на Acer всё ещё требует проверки.
- **Внешний SSD пока не зашифрован.** Secure Boot не заменяет шифрование. Не хранить секреты на установленной версии до создания шифрования и интерфейса учётных записей.
- Учётная запись irina сейчас с автологином и заблокированным парольным входом; безопасная GUI-установка пароля администратора — следующая задача.
- Установка Qwen 8B, Rust UEFI, USB-шифрования, Linphone и других тяжёлых компонентов — отдельная задача. Их не обещаем в базовом автоматическом наборе.
- Настоящий запуск этой новой версии пока не проверен на Acer, даже если GitHub CI зелёный. У прежнего Secure Boot-образа с Linux была подтверждена загрузка подписанной цепочки, но затем произошёл Casper kernel panic; текущий вариант устраняет зависимость от Casper.

Это отдельный экспериментальный путь постоянной установки, а не перепаковка предыдущего Live IMG.
