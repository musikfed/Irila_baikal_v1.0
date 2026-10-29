# Ирина Байкал 1.0: сборка через существующий WSL2 на диске F:

> **Если WSL перестал запускаться:** не продолжайте копирование и сборку. Сначала откройте [безопасную диагностику WSL](WSL_RECOVERY.md). Ошибка `WSL_E_DISTRO_NOT_FOUND` для `IrinaBuilder` до завершения импорта не означает пропажу основной Ubuntu. Экспортирование рабочей Ubuntu копирует все проекты и возможные закрытые файлы — не публикуйте архив или VHDX.

## Быстрый запуск из PowerShell — новый WSL-сборщик

В репозитории есть [Build-IrinaViaWSL.ps1](../windows/Build-IrinaViaWSL.ps1). Он объединяет установку Linux-инструментов **в WSL**, получение GitHub-исходников, подготовку `rootfs`, SquashFS, GPT/EFI и проверку копии IMG на `F:`.

Если ты **уже сделал** отдельный дистрибутив `IrinaBuilder` на F: (смотри ниже), достаточно запустить из PowerShell, открытого в папке репозитория:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\windows\Build-IrinaViaWSL.ps1"
~~~

Если хочешь использовать **уже установленную Ubuntu-24.04**, не создавая отдельной копии:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\windows\Build-IrinaViaWSL.ps1" -Distro Ubuntu-24.04
~~~

В этом варианте временные файлы будут храниться **в ext4 Ubuntu WSL**, то есть на диске, где установлен WSL (не обязательно F:). На F: автоматически скопируются только IMG и контрольная сумма. Если хочешь разместить **всё** на F:, сначала создай отдельную копию `IrinaBuilder` через `Prepare-IrinaBuilderOnF.ps1` и используй первый вариант.

Для полного набора программ:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\windows\Build-IrinaViaWSL.ps1" -Distro IrinaBuilder -Profile full -MaxImageMiB 8192
~~~

Для первого опыта **рекомендуется core**. Программа не перезаписывает существующие образы, проверяет F: и версию Ubuntu WSL, требует ввод `BUILD-IRINA`, не выбирает физический диск и **не запускает Rufus автоматически**. Если сборка остановилась (например, WSL не поддержал loop/GPT), не записывай неполный IMG.

**До запуска проверь, что F: не является целевым пустым внешним SSD 256 ГБ.**

---


**Для Acer Swift SF314-41 под Windows 11 Pro.** Не требуется новая виртуальная машина; уже установленной Ubuntu 24.04 достаточно. Процедура создаёт Linux-образ **в отдельной копии WSL на F:**, а внешний SSD 256 ГБ не затрагивает до отдельного этапа с Rufus.

**Важная проверка:** диск F: должен быть NTFS, с не менее ~40 GiB свободного места для первой сборки, и **не должен быть тем самым внешним USB SSD 256 ГБ**, который планируется прошивать. Для профиля `--full` лучше иметь 60–80 GiB. Если F: — целевой SSD, выберите другой рабочий диск.

## 1. Проверить Windows и существующую Ubuntu WSL

PowerShell в Windows (НЕ Ubuntu):

~~~powershell
wsl --list --verbose
wsl --version
Get-Volume -DriveLetter F
Get-Partition -DriveLetter F | Get-Disk |
  Select Number,FriendlyName,BusType,Size,IsBoot,IsSystem
~~~

Проверьте, что Ubuntu имеет имя `Ubuntu-24.04`, версия WSL — **2**, F: — NTFS и достаточно места. Если имя отличается, подставьте его во все команды ниже.

## 2. Сделать отдельную копию WSL на F: (исходная Ubuntu останется)

Скрипт [Prepare-IrinaBuilderOnF.ps1](../windows/Prepare-IrinaBuilderOnF.ps1) проверяет F: и WSL, запрашивает явное согласие `COPY-IRINA`, создаёт экспорт Ubuntu и импорт **новой** Linux-системы `IrinaBuilder` в `F:\irinabaikal\WSL-IrinaBuilder`.

Сначала загрузите этот PowerShell-скрипт из своего GitHub (а не из посторонних источников):

~~~powershell
New-Item -ItemType Directory -Force F:\irinabaikal
Invoke-WebRequest "https://raw.githubusercontent.com/musikfed/Irila_baikal_v1.0/main/windows/Prepare-IrinaBuilderOnF.ps1" -OutFile "F:\irinabaikal\Prepare-IrinaBuilderOnF.ps1"
Get-Content "F:\irinabaikal\Prepare-IrinaBuilderOnF.ps1"
~~~

Изучите код. После этого запустите в разрешающей локальные скрипты PowerShell-сессии:

~~~powershell
& "F:\irinabaikal\Prepare-IrinaBuilderOnF.ps1"
~~~

При отказе политики исполнения PowerShell сначала проверьте `Get-ExecutionPolicy -List`, не меняйте системную политику постоянно. Скрипт остановит другие WSL-сеансы через `wsl --shutdown` и спросит подтверждение; сохраните незаконченные работы в WSL до запуска.

**Без скрипта** эквивалентные команды (выполнять только после проверки F: и исходного WSL2):

~~~powershell
wsl --shutdown
wsl --export Ubuntu-24.04 F:\irinabaikal\Ubuntu-24.04-export.tar
wsl --import IrinaBuilder F:\irinabaikal\WSL-IrinaBuilder F:\irinabaikal\Ubuntu-24.04-export.tar --version 2
~~~

Никакого `wsl --unregister` не выполняем. Старый WSL оставляем. Экспортный TAR можно удалить **вручную после проверки**, что `IrinaBuilder` запускается, если требуется освободить место.

## 3. Запустить сборку Ubuntu на WSL ext4

В PowerShell:

~~~powershell
wsl -d IrinaBuilder -u root
~~~

В терминале IrinaBuilder (Linux):

~~~bash
apt-get update
apt-get install -y git debootstrap ubuntu-keyring rsync squashfs-tools \
  parted gdisk dosfstools e2fsprogs util-linux grub-efi-amd64-bin \
  grub-common python3
cd /root
git clone https://github.com/musikfed/Irila_baikal_v1.0.git
cd Irila_baikal_v1.0

# Безопасная проверка loop/GPT внутри временного файла 96 MiB
bash scripts/check_wsl_loop.sh

# Создание rootfs -> SquashFS -> GPT/UEFI IMG -> копия на F:
bash scripts/build_in_wsl.sh --core
~~~

Проверка loop/GPT **не обращается к физическим дискам**. Если WSL не поддерживает loop-разделы, остановитесь. Не подключайте через WSL физические SSD ради обхода этого ограничения. Можно использовать GitHub Actions или Ubuntu Live USB.

`--core` — компактная первая версия XFCE/Irina Shell; `--full` добавляет LibreOffice, GIMP, Inkscape, Thunderbird, Linphone и мини-игры. Для `--full` может потребоваться `bash scripts/build_in_wsl.sh --full --max-image-mib 8192`; модель Qwen 8B не поместится в предел 5 ГиБ.

### Где лежат файлы

После **успешной** сборки и повторной проверки хеша:

~~~text
F:\irinabaikal\irina_baikal_1.0.img
F:\irinabaikal\irina_baikal_1.0.img.sha256
~~~

Сборочные данные в `/srv/irina` внутри отдельного WSL `IrinaBuilder` тоже физически хранятся на F: в `WSL-IrinaBuilder\ext4.vhdx`, а не в каталоге NTFS. Если сборка завершилась ошибкой, готового пригодного образа **нет**.

## 4. Проверить в Windows, затем записать на внешний SSD 256 ГБ

После `exit` из WSL открыть PowerShell из исходного репозитория либо скачать [flash_irina.py](../scripts/flash_irina.py) в папку Windows:

~~~powershell
Invoke-WebRequest "https://raw.githubusercontent.com/musikfed/Irila_baikal_v1.0/main/scripts/flash_irina.py" -OutFile "F:\irinabaikal\flash_irina.py"
py -3.13 "F:\irinabaikal\flash_irina.py" --image "F:\irinabaikal\irina_baikal_1.0.img"
~~~

Скрипт проверяет SHA256 и перечисляет диски Windows **только для чтения**. После успешной проверки в [Rufus](https://rufus.ie/) выбрать внешний USB M.2 SSD **256 ГБ** и готовый IMG, записать в raw/DD-режиме, если запрашивается. Дополнительное форматирование не нужно. **Windows SSD 512 ГБ не выбирать.**

После завершения выключить Acer, нажать **F12** и выбрать внешний накопитель. При включённом Secure Boot неподписанный GRUB может быть заблокирован: до изменения настроек UEFI убедиться в наличии сохранённого ключа BitLocker/шифрования Windows.

## Статус и ограничения

Это *экспериментальные* скрипты. Пройдены только базовые статические тесты, **полный реальный запуск в WSL и первая загрузка Acer ещё не подтверждены**. Система использует read-only SquashFS + RAM overlay, но не подписанный Rust UEFI загрузчик, не persistent DATA, не готовую Qwen 8B. Изменения и документы в RAM теряются при перезапуске. Нельзя хранить там рабочую почту и секреты до настройки постоянного DATA-раздела.
