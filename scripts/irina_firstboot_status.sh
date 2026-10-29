#!/usr/bin/env bash
# Read-only progress terminal shown on Irina XFCE login.
set -u
STATE=/var/lib/irina-firstboot/complete
LOG=/var/log/irina-firstboot.log
if [[ -f "$STATE" ]]; then
  echo 'Ирина Байкал: программы уже установлены.'
  exit 0
fi
echo 'Ирина Байкал: первичная настройка выполняется автоматически.'
echo 'Для установки программ подключи интернет.'
echo 'Этим рабочим столом уже можно пользоваться.'
while [[ ! -f "$STATE" ]]; do
  echo
  date '+%H:%M:%S — проверка установки'
  if [[ -r "$LOG" ]]; then tail -n 8 "$LOG"; else echo 'Ожидание сети и сервиса установки...'; fi
  sleep 12
done
echo 'Готово: программы установлены!'
read -r -p 'Нажми Enter для закрытия окна: ' _ || true
