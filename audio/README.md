# Ирина Байкал 1.0 — космическое аудиоинтро

**Звуковой образ:** воздушный космический фон, мягкий низкий синтезатор, несколько хрустальных импульсов и тихий женский синтетический тембр:

> «Ирина Байкал систем один точка ноль»

Продолжительность около 9,25 секунд, стерео 44,1 кГц. Фон — оригинально синтезированный.

**Голос:** текущий автономный прототип создаётся через eSpeak (`ru+f3`) с небольшим дыхательным шумом. Это не реальная запись женщины и пока не естественный шёпот. Генератор может принять записанную или лицензированную WAV-дорожку через `--voice-wav`. Не добавлять чужие записи без разрешения.

## Генерация

Workflow `.github/workflows/build-intro.yml` устанавливает numpy, scipy, espeak и ffmpeg, создаёт `ui/web/assets/irina_intro.mp3` и публикует GitHub Actions artifact. При push на main он также коммитит MP3 в репозиторий.

Локально на Linux:
```bash
sudo apt-get install espeak ffmpeg
python3 -m pip install numpy scipy
python3 audio/generate_intro.py --output /tmp/irina_intro.wav
ffmpeg -y -i /tmp/irina_intro.wav -codec:a libmp3lame -qscale:a 3 ui/web/assets/irina_intro.mp3
```

Своё голосовое WAV (PCM 16 bit): `python audio/generate_intro.py --voice-wav /path/to/voice.wav --output /tmp/irina_intro.wav`. Нужна запись с согласованной фразой.

## Воспроизведение

Ubuntu: после входа в рабочий сеанс XFCE, не при старте UEFI. `audio/play_intro.sh` использует `mpg123` или `ffplay`. Скрипт `ui/install_ubuntu.sh` копирует интерфейс и аудио и создаёт XDG-autostart запись. Выполнять только в тестовой Ubuntu VM или в явно выбранной Linux-системе.

Windows: для предпросмотра кнопка **♪ Звук старта** в быстрых настройках оболочки. Автовоспроизведение в браузерах может блокироваться; никакого звука при обновлении страницы не запускаем.

Отключение интро на Linux:
```bash
mkdir -p "$HOME/.config/irina"
touch "$HOME/.config/irina/disable-intro"
```

Включение: `rm "$HOME/.config/irina/disable-intro"`. Для сохранения настроек и почты в будущей Read-Only ОС нужен постоянный DATA-раздел SSD.

**Статус:** звуковой прототип и скрипты, не готовый Acer-проверенный загрузочный образ.
