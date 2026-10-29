#!/usr/bin/env python3
"""Small graphical status view; no terminal or admin rights for the user."""
from pathlib import Path
import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib

STATUS = Path("/var/lib/irina/setup-status")
READY = Path("/var/lib/irina/software-ready")
GROW = Path("/var/lib/irina/root-expanded")


class StatusWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Ирина Байкал — подготовка системы")
        self.set_default_size(560, 210)
        self.set_border_width(20)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.connect("destroy", Gtk.main_quit)
        area = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.add(area)
        heading = Gtk.Label()
        heading.set_markup("<span size='large' weight='bold'>Добро пожаловать в Ирину Байкал!</span>")
        heading.set_xalign(0)
        area.pack_start(heading, False, False, 0)
        self.label = Gtk.Label(label="Проверяю подготовку системы...")
        self.label.set_line_wrap(True)
        self.label.set_xalign(0)
        area.pack_start(self.label, False, False, 0)
        self.spinner = Gtk.Spinner()
        self.spinner.start()
        area.pack_start(self.spinner, False, False, 0)
        self.small = Gtk.Label(label="После подключения Wi-Fi программы установятся сами. Можно пользоваться рабочим столом.")
        self.small.set_line_wrap(True)
        self.small.set_xalign(0)
        area.pack_start(self.small, False, False, 0)
        close = Gtk.Button(label="Скрыть окно (настройка продолжится)")
        close.connect("clicked", lambda _widget: Gtk.main_quit())
        area.pack_start(close, False, False, 0)
        GLib.timeout_add_seconds(3, self.refresh)
        self.refresh()
        self.show_all()

    def refresh(self):
        try:
            state = STATUS.read_text(encoding="utf-8").strip()
        except (OSError, UnicodeError):
            state = "Загружаю список задач..."
        self.label.set_text(state)
        if READY.is_file():
            self.spinner.stop()
            self.small.set_text("Программы установлены. Файлы и настройки сохраняются на SSD.")
        elif not GROW.is_file():
            self.small.set_text("Проверяю размер внешнего SSD. Интернет для проверки диска не нужен.")
        return True


if __name__ == "__main__":
    window = StatusWindow()
    Gtk.main()
