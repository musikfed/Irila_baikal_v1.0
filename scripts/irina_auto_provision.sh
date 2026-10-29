#!/usr/bin/env bash
# First-boot unattended app installation. Re-run by systemd timer if offline.
# NEVER changes bootloader, disk partitioning, TPM, BitLocker, Windows or keys.
set -Eeuo pipefail
umask 022
mkdir -p /var/lib/irina /var/log
STATUS=/var/lib/irina/setup-status
LOG=/var/log/irina-software.log
status() { printf '%s\n' "$1" >"$STATUS"; chmod 644 "$STATUS"; echo "IRINA: $1"; }
exec >> "$LOG" 2>&1
echo "IRINA provisioning: $(date -u +%FT%TZ)"
[[ -f /etc/irina-installed-marker ]] || exit 0
[[ "$(cat /etc/irina-installed-marker)" == IRINA_INSTALLED_USB_R1 ]] || exit 0
if [[ -f /var/lib/irina/software-ready && -f /var/lib/irina/software-extras-ready ]]; then
  status "Готово. Офис, графика, почта, SIP и игры установлены, можно работать."
  exit 0
fi
status "Подготовка: проверяю интернет и доступное место..."
if ! getent ahostsv4 archive.ubuntu.com >/dev/null 2>&1; then
  status "Ожидаю подключение Wi-Fi. Подключитесь через значок сети; повторю автоматически."
  exit 0
fi
AVAIL_KB="$(df -Pk / | awk 'NR==2 {print $4}')"
if (( AVAIL_KB < 1900000 )); then
  status "Недостаточно места. Проверка расширения SSD; повторю установку автоматически."
  exit 0
fi
# Avoid automatic command prompting, kernel/EFI changes or repartitioning.
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
status "Сеть доступна. Обновляю списки пакетов Ubuntu..."
if ! apt-get -o Acquire::Retries=2 update; then
  status "Сервер Ubuntu временно недоступен; установка повторится автоматически."
  exit 0
fi
if [[ ! -f /var/lib/irina/software-ready ]]; then
  status "Устанавливаю LibreOffice, GIMP, Inkscape и Thunderbird..."
  if ! apt-get -y --no-install-recommends -o Dpkg::Options::=--force-confold install \
    libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-l10n-ru \
    gimp inkscape thunderbird; then
    status "Основные программы: проблема сети/пакетов; повторю установку автоматически."
    exit 0
  fi
  touch /var/lib/irina/software-ready
fi
if [[ ! -f /var/lib/irina/software-extras-ready ]]; then
  status "Основные приложения готовы. Подключаю Linphone и небольшие игры..."
  if ! apt-get -y --no-install-recommends -o Dpkg::Options::=--force-confold install \
    linphone-desktop aisleriot gnome-mines gnome-mahjongg; then
    status "Офис и почта готовы. SIP/игры пока недоступны, повторю автоматически."
    exit 0
  fi
  touch /var/lib/irina/software-extras-ready
fi
status "Готово. Офис, графика, почта, SIP и игры установлены."
echo "IRINA provisioning success: $(date -u +%FT%TZ)"
