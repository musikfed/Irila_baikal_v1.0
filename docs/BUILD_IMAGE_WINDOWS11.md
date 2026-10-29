# Сборка «Ирина Байкал 1.0» в Windows 11 через Ubuntu VM

**Статус: проверочный сборщик. IMG ещё не собран и не испытан на Acer.**

Исходные данные: Acer Swift 3 SF314-41, Ryzen 5 3500U, Vega 8, 20 ГБ RAM. Внутренний SSD (~512 ГБ) с Windows 11 Pro **не трогать**. Внешний SSD 256 ГБ USB 3.0 уже **пустой, без разделов**, и для записи готового образа **не требует предварительного форматирования**.

## 1. Создание сборочной VM на Windows 11 Pro

Включить Hyper-V в компонентах Windows, создать виртуальную машину **Generation 2, Ubuntu 24.04 x86_64**, ориентир **8 ГБ RAM, 4 CPU, VHDX 60–80 ГБ**, с интернетом. Если в Hyper-V используется Secure Boot, для Ubuntu выбрать шаблон Microsoft UEFI Certificate Authority.

Ни USB SSD, ни внутренний диск Acer **не подключать к виртуальной машине как raw/block device**. Сборщик создаёт только файл IMG на виртуальном диске.

В терминале **Ubuntu VM**, не в PowerShell:
```bash
sudo apt update
sudo apt install -y git debootstrap parted gdisk dosfstools e2fsprogs grub-efi-amd64-bin grub2-common rsync python3 ubuntu-keyring qemu-system-x86 ovmf
git clone https://github.com/musikfed/Irila_baikal_v1.0.git
cd Irila_baikal_v1.0
sudo mkdir -p /srv/irina
sudo bash scripts/build_irina_img.sh --output /srv/irina/irina_baikal_1.0.img --full
```

Скрипт попросит ввести `BUILD`. Для меньшего состава приложений использовать `--core`. Он создаёт образ как **новый файл** и отказывается перезаписывать существующий.

После **успешной** сборки ожидаются:
- `/srv/irina/irina_baikal_1.0.img` — **16 GiB** GPT/UEFI raw;
- `/srv/irina/irina_baikal_1.0.img.sha256` — SHA-256 образа;
- `/srv/irina/irina_baikal_1.0.img.login.txt` — локальный пароль пользователя `irina`, файл приватный, **не отправлять в GitHub**.
- `.FAILED` — признак прерванной сборки. Такой IMG **нельзя записывать на SSD**.

Система: Ubuntu 24.04 XFCE, Linux-ядро и linux-firmware, Irina Shell, космическая звуковая заставка, приложения согласно `--full`/ `--core`. Разметка: EFI FAT32 512 MiB, ROOT ext4 около 12 GiB, DATA ext4 ~3,5 GiB для `/home`. ВАЖНО: корень **пока записываемый**. SquashFS/OverlayFS, Rust UEFI, подписанная загрузка, локальный Ollama/Qwen и Qt Browser **ещё не встроены** в этот минимальный образ.

## 2. Проверка UEFI в QEMU

```bash
bash scripts/test_irina_qemu.sh /srv/irina/irina_baikal_1.0.img
```

Скрипт использует UEFI OVMF и snapshot=on, не меняет исходный образ. Если виртуальная машина не загрузила GRUB/Ubuntu/Irina Shell, не переходить к записи SSD; собрать логи и исправить проблему.

Проверка SHA:
```bash
cd /srv/irina
sha256sum -c irina_baikal_1.0.img.sha256
```

## 3. Перенос с VM в Windows

Использовать общую папку/SMB или SCP, перенести IMG и SHA256. Нужно свободное место под 16 GiB. **Не подключать физический SSD напрямую к VM.**

В PowerShell Windows проверить:
```powershell
(Get-FileHash "D:\Irina\irina_baikal_1.0.img" -Algorithm SHA256).Hash
```

Это пример пути; реальный путь может отличаться. Сравнить хеш с файлом `.sha256`.

## 4. Прошивка уже пустого USB M.2 SSD 256 ГБ

В PowerShell администратора проверить носители **только чтением**:
```powershell
Get-Disk | Select Number,FriendlyName,BusType,Size,IsBoot,IsSystem | Format-Table -AutoSize
```

Убедиться, что нужный диск **USB**, ёмкость ~256 GB, не загрузочный и не системный. По модели и **отключению/повторному подключению** подтвердить выбранный внешний диск. **Номер диска может меняться.**

Скачать Rufus с https://rufus.ie/ , выбрать образ `.img`, **только внешний SSD 256 ГБ**, режим прямой записи (DD/raw) при запросе. В дополнительных опциях Rufus иногда требуется «Show USB hard drives». Сам IMG создаст разметку, предварительное форматирование не требуется.

Выбрать внешний SSD через меню загрузки Acer F12 (если разрешено в UEFI). Экспериментальный GRUB **не подписан для Secure Boot**. Для первой проверки может потребоваться отключение Secure Boot, но это снижает защиту Windows и может вызвать запрос BitLocker recovery key. **До любых изменений UEFI убедиться в наличии ключа восстановления Windows.**

## 5. После записи

Первые ~16 GiB будут размечены; оставшееся пространство 256 GB SSD останется неразмеченным. После успешной загрузки раздел DATA можно расширить через GParted, запущенный с другого Linux Live-носителя, когда DATA **размонтирован**. На работающей системе изменять этот раздел нельзя.

Образ не шифрует DATA и автоматически входит в пользовательский сеанс: **не использовать его для ценной почты и секретов**, пока не будет добавлен LUKS2 и контроль загрузочной цепочки. Проверить Wi-Fi QCA61x4A, Realtek, Vega 8, WebCam и сон на самом Acer.

**Ограничение:** скрипт прошёл только проверки синтаксиса GitHub CI, а настоящая сборка в Ubuntu VM и загрузка на Acer **ещё не подтверждены**. Разработку SquashFS + OverlayFS начать после успешного MVP-старта.
