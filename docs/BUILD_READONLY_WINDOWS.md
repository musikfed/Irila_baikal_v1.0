# Сборка Irina Baikal 1.0: SquashFS + RAM OverlayFS

**Основной путь по ТЗ, пока экспериментальный.** Образ ещё не собирался в окружении Acer. Для проверки используем настоящий Acer через F12 без обязательной тестовой VM.

## Схема

Windows 11 Pro на внутреннем SSD НЕ трогаем. Изолированная Ubuntu 24.04 rootfs создаётся из официальных пакетов в WSL2 (или Ubuntu Live-USB), затем упаковывается в SquashFS. Скрипт запекания создаёт новый файл образа GPT: EFI/FAT32 512 MiB, ext4 IRINA_LIVE, каталог /casper/filesystem.squashfs, ядро и initramfs. GRUB загружает casper, который создаёт временный OverlayFS в RAM, без сохранения записей.

Ограничение готового IMG по умолчанию 5 ГиБ. Профиль --full и Qwen 8B могут превысить бюджет, тогда сборка честно прервётся. Начинать рекомендуется с --core. На этой стадии вместо Rust используется неподписанный GRUB. Подпись, Rust UEFI, постоянный /home и готовая модель Qwen ещё требуют отдельного этапа.

## Вариант А: Windows 11 Pro + WSL2, без отдельной тестовой VM

WSL2 использует лёгкую виртуализацию для сборочных Linux-инструментов, но отдельную Ubuntu VM с графическим рабочим столом или QEMU создавать не надо.

В PowerShell администратора (если WSL2 ещё нет):

~~~powershell
wsl --install -d Ubuntu-24.04
~~~

После возможной перезагрузки:

~~~powershell
wsl -d Ubuntu-24.04
~~~

В Ubuntu-терминале WSL2:

~~~bash
sudo apt update
sudo apt install -y git debootstrap ubuntu-keyring rsync squashfs-tools parted gdisk dosfstools e2fsprogs util-linux grub-efi-amd64-bin grub-common python3
git clone https://github.com/musikfed/Irila_baikal_v1.0.git
cd Irila_baikal_v1.0
sudo bash scripts/prepare_source.sh --stage /srv/irina/rootfs --core
sudo bash scripts/bake_image.sh --stage /srv/irina/rootfs --output /srv/irina/irina_baikal_1.0.img
cd /srv/irina
sha256sum -c irina_baikal_1.0.img.sha256
~~~

Важные условия: исходный rootfs должен лежать на файловой системе Linux внутри WSL, не в /mnt/c. Нужны десятки ГБ свободного места. WSL2 может не поддержать loop-разделы или нужные монтирования — в таком случае используйте Ubuntu Live-USB, а не подключайте физический внутренний SSD к WSL.

Для полного офиса и графики вместо --core в первой команде выберите --full. Если готовая система не укладывается в лимит, параметр --max-image-mib 8192 в bake_image.sh разрешит больший образ. Не пытайтесь вместить Qwen 8B в 3–5 ГБ.

## Вариант Б: Ubuntu Live USB, без какой-либо виртуализации

Загрузить официальную Ubuntu 24.04 в режиме Try Ubuntu с ДРУГОЙ флешки через F12 (не устанавливать на внутренний SSD). Нужен отдельный Linux-носитель со свободным местом под сборку; нельзя строить образ на самом SSD, который затем будет очищен записью. В Ubuntu Live выполнить те же команды после установки зависимостей. Это работа с пакетами Linux, а не перенос Windows в Linux.

## Перенос и запись в Windows

В проводнике Windows образ WSL доступен по адресу:

~~~text
\\wsl.localhost\Ubuntu-24.04\srv\irina\
~~~

Скопировать IMG и .sha256 на файловую систему Windows. В Windows PowerShell запустить из папки репозитория (путь пример):

~~~powershell
py -3.13 scripts\flash_irina.py --image "C:\IrinaBaikal\irina_baikal_1.0.img"
~~~

Скрипт ПРОВЕРЯЕТ SHA256 и показывает диски ТОЛЬКО ДЛЯ ЧТЕНИЯ. Он не форматирует и не записывает ничего в Windows. Затем в Rufus https://rufus.ie/ вручную выбрать только внешний пустой M.2 SSD 256 ГБ USB 3.0 и IMG. Если Rufus предлагает DD/raw — использовать его. Разметка GPT/EFI появится автоматически, заранее форматировать не нужно.

Перед выбором внешнего USB-диска убедиться по BusType USB, модели, 256 ГБ, флагам IsSystem/IsBoot=false и физическому отключению/подключению, что это НЕ внутренний SSD с Windows. На внутреннем Windows SSD ничего не меняем. Файлы .FAILED нельзя записывать на диск.

## Первая загрузка

Выключить Acer, выбрать внешний диск через F12. Неподписанный GRUB может не работать при включённом Secure Boot. Прежде чем менять настройку Secure Boot, убедиться, что сохранён ключ восстановления BitLocker/шифрования Windows. На первом запуске проверить Wi-Fi QCA61x4A, Vega 8, Realtek, HD WebCam, звук, Irina Shell, язык и временный RAM-overlay. Если не загружается — фото экрана ошибки для исправления.

Внимание: пользовательские письма, файлы, настройки и модель, сохранённые в RAM-overlay, исчезнут при перезапуске. Для постоянного /home в будущей сборке будет настроен отдельный DATA-раздел. После записи компактного IMG оставшееся пространство 256 ГБ SSD останется неразмеченным.

**Статус:** скрипты подготовки и запекания, затем реальные испытания F12; ни загрузку, ни размер результата на Acer пока нельзя гарантировать.
