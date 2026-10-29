#!/usr/bin/env python3
"""Build a public, EXIF-free photographic gallery from owner-supplied Acer archive.

Only image bytes are decoded; ZIP paths are NEVER extracted on disk.
Generated preview images are downsized, EXIF and incidental metadata removed.
This tool cannot independently determine if an image contains personal info.
"""
from __future__ import annotations

import argparse
import io
import re
from pathlib import Path
from zipfile import ZipFile

from PIL import Image, ImageOps, UnidentifiedImageError

IMAGES = {
    "223258": ("Главный экран Ирины", "Подтверждён запуск фирменной оболочки"),
    "223304": ("Меню приложений", "Панель задач и меню на живом Acer"),
    "223316": ("Ирина Байкал 1.0", "Крупный план новой сине-голубой темы"),
    "223501": ("Первое подключение", "Диагностика пользовательского интерфейса"),
    "223510": ("Камера", "Invalid constraint: требуется проверка WebRTC"),
    "223517": ("Оформление", "Переключатели цвета и профиль Acer"),
    "223545": ("Почта", "Thunderbird пока не установлен"),
    "223552": ("Файлы Ирины", "Диалог выбора файлов"),
    "223604": ("Браузер", "Ошибка открытия сайта, требуется проверка соединения"),
    "223624": ("Интернет", "Панель открытия адреса сайта"),
    "223634": ("Телефон", "Linphone пока не установлен"),
    "223728": ("XFCE", "Меню графической среды"),
    "223742": ("Настройки XFCE", "Панель уведомлений и рабочего стола"),
    "223756": ("Файловый менеджер", "Каталоги Linux"),
    "223854": ("Терминал", "Установленное ядро и имя пользователя"),
    "223913": ("Процессы", "Рабочая система и около 17,9 ГиБ RAM"),
    "223941": ("Корневой раздел SSD", "df -h: /dev/sdb2 — 235 ГиБ, /boot/efi — 511 МБ"),
    "224025": ("Системное меню", "Графическое завершение сеанса"),
}


def create_gallery(archive: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    out_images = destination / "photos"
    out_images.mkdir(exist_ok=True)
    written = []
    with ZipFile(archive, "r") as z:
        entries = z.infolist()
        if len(entries) > 30:
            raise ValueError("Too many archive entries (>30)")
        total = sum(e.file_size for e in entries)
        if total > 40 * 1024 * 1024:
            raise ValueError("Original archive is too large (>40 MiB)")
        for entry in entries:
            # ZIP entry name is inspected but not interpreted as path.
            name = entry.filename
            if not re.fullmatch(r"IMG_20261029_([0-9]{6})\.jpg", name):
                raise ValueError(f"Unexpected archive filename: {name!r}")
            key = name[-10:-4]
            if key not in IMAGES:
                raise ValueError(f"Unknown owner photo: {name}")
            if entry.file_size > 5 * 1024 * 1024:
                raise ValueError(f"One screenshot >5 MiB: {name}")
            raw = z.read(entry)
            try:
                with Image.open(io.BytesIO(raw)) as source:
                    if source.format != "JPEG":
                        raise ValueError(f"Not a JPEG: {name}")
                    if source.width * source.height > 20_000_000:
                        raise ValueError(f"Image too large: {name}")
                    photo = ImageOps.exif_transpose(source).convert("RGB")
                    photo.thumbnail((1400, 800), Image.Resampling.LANCZOS)
                    output_name = f"{key}.jpg"
                    photo.save(out_images / output_name, "JPEG", quality=79, optimize=True)
            except (OSError, UnidentifiedImageError) as exc:
                raise ValueError(f"Invalid JPEG: {name}") from exc
            written.append((key, name, output_name))
    if len(written) != len(IMAGES) or len(set(k for k, _, _ in written)) != len(IMAGES):
        raise ValueError("Archive must contain exactly the 18 original first-boot photos")
    lines = [
        "# Ирина Байкал 1.0 — первый запуск на Acer",
        "",
        "**29 октября 2026 · реальные фотографии с Acer Swift 3 SF314-41.**",
        "Снимки пользователя с оригинального физического экрана, не рендер и не эмулятор.",
        "Превью уменьшены и очищены от EXIF; архив оригиналов не обязателен для просмотра.",
        "",
        "> Фото показывают загрузку и графический сеанс, но не подтверждают исправность всех приложений.",
        "> Прежде чем выкладывать новые скриншоты в публичный GitHub, проверьте наличие личных данных.",
        "",
        "## Технические итоги",
        "",
        "- Secure Boot принял подписанную Ubuntu-цепочку до ядра.",
        "- Установленная система вышла на XFCE / Xorg; ошибки Casper из прежней Live-сборки нет.",
        "- В терминале: `/dev/sdb2` смонтирован в `/`, размер **235 ГиБ**; `/dev/sdb1` — EFI 511 МБ.",
        "- `top` показывает около **17,9 ГиБ RAM**, работающий Xorg и xfwm4.",
        "- Камера: `Invalid constraint`; почта и SIP: приложения пока отсутствуют; браузеру нужна диагностика сети.",
        "",
        "## Фотоотчёт",
        "",
    ]
    for key, name, output_name in written:
        title, desc = IMAGES[key]
        lines += [
            f"### {title}",
            "",
            f"![{title}](photos/{output_name})",
            "",
            f"*{desc} — исходный снимок `{name}`.*",
            "",
        ]
    lines += [
        "## Следующие шаги",
        "",
        "1. Отладить разрешения камеры, сеть и запуск SIP/почты.",
        "2. Оформить штатную установку программ и проверку подписей пакетов.",
        "3. Добавить необязательную русскую звуковую заставку с шумом байкальских волн.",
        "4. Заменить фото экрана на нативные скриншоты PNG после проверки личных данных.",
    ]
    (destination / "index.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Published {len(written)} sanitized JPEGs to {out_images}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("docs/first_boot"))
    args = parser.parse_args()
    create_gallery(args.zip, args.output)
