# «Ирина Байкал 1.0 Secure Boot» — ВТОРОЙ отдельный IMG

**29 октября 2026.** Пробная сборка для Acer Swift 3 SF314-41 с **Secure Boot = Enabled** и Windows 11 Pro с BitLocker. Репозиторий **остаётся публичным**; собственные секретные ключи, MOK-пароли и пользовательские сертификаты нигде не публикуются.

## Два независимых образа

| Вариант | Имя файла для Windows F:\irinabaikal | GitHub Actions | Загрузка |
|---|---|---|---|
| Первый, сохранённый | `irina_baikal_1.0.img` + `.sha256` | [Build Irina Baikal read-only IMG](../.github/workflows/build-readonly-img.yml) | Обычный, НЕподписанный GRUB; с включённым Secure Boot Acer уже выдал Security Boot Fail |
| Второй, экспериментальный | `irina_baikal_1.0_secureboot.img` + `.sha256` | [Build Irina Baikal Secure Boot IMG](../.github/workflows/build-secureboot-img.yml) | Ubuntu shim с двойной подписью Microsoft (2011 + 2023) → Canonical-подписанный GRUB → подписанное ядро Ubuntu |

**Первый IMG не удалять, не заменять, не переименовывать.** Во втором имени обязательно присутствует суффикс `_secureboot`. Оба workflow имеют разные имена, файлы результата и артефакты; каждый новый успешный артефакт хранится до 30 дней (в пределах настроек GitHub). Локальный первый IMG на F: сохраняется бессрочно, пока пользователь сам не удалит.

## Что именно изменилось

Новый [`scripts/bake_image_secureboot.sh`](../scripts/bake_image_secureboot.sh) создаёт **новый файл IMG**, а старый `scripts/bake_image.sh` не изменён. Ubuntu Noble устанавливается в отдельный временный rootfs на облачном Linux runner. Подписанные EFI-файлы **извлекаются через apt-get download + dpkg-deb**, без `grub-install` и без изменения UEFI/NVRAM runner.

- `shim-signed`: файл `/usr/lib/shim/shimx64.efi.dualsigned` копируется как `EFI/BOOT/BOOTX64.EFI`.
- `grub-efi-amd64-signed`: `/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed` копируется как `EFI/BOOT/grubx64.efi`.
- MokManager `mmx64.efi` копируется рядом.
- `linux-image-generic` содержит готовое Canonical-подписанное ядро. На EFI FAT32 копируются подписанный `casper/vmlinuz` и `casper/initrd`; SquashFS остаётся на другом GPT/ext4 разделе.
- На этапе сборки `sbverify --list` должен обнаружить подписи у shim, GRUB, MokManager и ядра. Для shim дополнительно проверяем наличие **двух** EFI-подписей (переход Microsoft UEFI CA 2011 → 2023, актуален для Acer 2021 года). Это **не гарантирует** доверие Acer к конкретному shim, если UEFI DBX/SBAT содержит отзыв. Это НЕ проверка ключей, записанных в UEFI Acer.
- Готовый IMG и его `.sha256` проверяются сначала в Linux, затем в артефактной копии.

**Не создаём и не кладём в GitHub никаких приватных ключей.** Верификация на Acer зависит от доверенных сертификатов/DBX/SBAT, политик UEFI и совместимости подписанного GRUB с данной конфигурацией. Даже `Success` в GitHub Actions **не гарантирует успешную физическую загрузку**. Текущая система использует непроверяемый отдельно initrd и SquashFS (нет dm-verity / измерения корня). Следовательно это не полноценная защищённая система от модификаций с физическим доступом.

## Как создать и скачать второй образ

1. GitHub → репозиторий → **Actions** → **Build Irina Baikal Secure Boot IMG** → успешный запуск (workflow стартует также автоматически при изменении файла workflow / нового скрипта). Для ручного запуска: **Run workflow**, branch main, `profile=core`, `max_mib=5120`.
2. Внизу успешного запуска найти **Artifacts → irina-baikal-1.0-secureboot-img**. Если статус Failure либо отсутствует артефакт — **скачивать нечего**; не использовать старый артефакт как новый.
3. Сохранить ZIP и извлечь в `F:\irinabaikal` оба файла:
   - `irina_baikal_1.0_secureboot.img`
   - `irina_baikal_1.0_secureboot.img.sha256`
4. Проверить только **НОВЫЙ** образ (обычный PowerShell):

~~~powershell
$img = "F:\irinabaikal\irina_baikal_1.0_secureboot.img"
$expected = ((Get-Content "$img.sha256" -Raw).Trim() -split '\s+')[0]
$actual = (Get-FileHash $img -Algorithm SHA256).Hash
if ($actual -ieq $expected) { Write-Host "SECUREBOOT IMG SHA256 OK" -ForegroundColor Green }
else { throw "SECUREBOOT IMG SHA256 ERROR!" }
~~~

## Как испытать на Acer

Перед повторной записью скопировать/сохранить первый IMG `F:\irinabaikal\irina_baikal_1.0.img` и SHA256 — **не удалять их**.

**На внешнем SSD 256 ГБ одновременно останется только тот образ, который последний записан Rufus.** Перезапись USB SSD новым образцом **удалит прежние GPT-разделы на самом внешнем SSD**. Это не уничтожит файлы IMG, лежащие на F:, и не затронет внутренний Windows NVMe. Перед START вручную проверить устройство USB **Realtek RTL9210B-CG / ~238,47 ГиБ**; NVMe с Windows и диски D:/F: не выбирать.

- UEFI Acer оставить в режиме **UEFI + Secure Boot Enabled**. Не переключать MBR/Legacy, не изменять ключи, не выключать BitLocker ради нового образа.
- В Rufus выбрать только внешний USB SSD 256 ГБ и **новый** `*_secureboot.img`, подтвердить его стирание; после записи Windows может не показывать ext4-раздел в Проводнике — это ожидаемо.
- Перезагрузить Acer и выбрать внешний SSD через **F12**.
- Если снова `Security Boot Fail`, `Verification failed`, `SBAT`, `bad shim signature`, ошибка GRUB или чёрный экран, **сфотографировать точный текст**, не менять настройки BIOS наугад; нужна доработка signed цепочки и диагностика.

## Ограничения

Core включает Ubuntu 24.04, XFCE, Irina Shell, Epiphany, Hrag; нет Qwen 8B, persistent DATA, собственного подписанного Rust UEFI. Данные в RAM OverlayFS пропадают после перезагрузки.

Источники: [Ubuntu UEFI Secure Boot](https://documentation.ubuntu.com/security/security-features/platform-protections/secure-boot/), пакеты [shim-signed](https://packages.ubuntu.com/noble/shim-signed), [grub-efi-amd64-signed](https://packages.ubuntu.com/noble/grub-efi-amd64-signed).
