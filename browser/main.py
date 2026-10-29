"""Irina Baikal Browser — native Qt WebEngine prototype for Windows and Linux.

Install: uv pip install --python .venv/Scripts/python.exe -r browser/requirements.txt
Run:     .venv/Scripts/python.exe browser/main.py
Security: only grants webcam/microphone permissions after an explicit dialog.
"""
from __future__ import annotations

import sys
from pathlib import Path

from urltools import address_to_url

try:
    from PySide6.QtCore import Qt, QUrl
    from PySide6.QtGui import QKeySequence, QShortcut
    from PySide6.QtWidgets import (
        QApplication, QHBoxLayout, QLineEdit, QMainWindow, QMessageBox,
        QPushButton, QTabWidget, QVBoxLayout, QWidget
    )
    from PySide6.QtWebEngineWidgets import QWebEngineView
except ImportError as exc:
    raise SystemExit("Не хватает PySide6 / Qt WebEngine. Смотри browser/README.md") from exc


ROOT = Path(__file__).resolve().parent
HOME = ROOT / "home.html"
START_URL = QUrl.fromLocalFile(str(HOME))
STYLE = """
QMainWindow, QWidget { background-color: #071d2b; color: #f2ffff; font-family: 'Segoe UI', Arial; }
QWidget#topbar { background-color: #092838; border-bottom: 1px solid #276774; }
QPushButton { color: #e5ffff; background-color: #164457; border: 1px solid #2c7180;
              border-radius: 10px; min-width: 30px; min-height: 30px; padding: 3px 9px; }
QPushButton:hover { background-color: #15766d; }
QPushButton#brand { color: #e0ffed; background: #10756b; font-weight: 700; }
QLineEdit { background: #11394b; color: white; border: 1px solid #2f8991;
            border-radius: 13px; min-height: 34px; padding: 3px 12px; selection-background-color: #187f7f; }
QTabWidget::pane { border: 0; }
QTabBar::tab { background: #113649; color: #c6e5e7; padding: 8px 22px;
               margin-right: 3px; border-top-left-radius: 9px; border-top-right-radius: 9px; }
QTabBar::tab:selected { background: #176f71; color: white; }
QTabBar::tab:hover { background: #216574; }
"""


class BrowserPage(QWebEngineView):
    def __init__(self, host: "IrinaBrowser"):
        super().__init__(host)
        self.host = host
        # Requires Qt WebEngine 6.8+; dependency is >=6.10.
        self.page().permissionRequested.connect(self.ask_permission)

    def createWindow(self, _window_type):
        return self.host.new_tab()

    def ask_permission(self, permission):
        # Web permissions can expose sensitive data. Always require confirmation.
        site = permission.origin().toString()
        name = permission.permissionType().name
        is_media = "Media" in name or "DesktopVideoCapture" in name
        if not is_media:
            permission.deny()
            return
        answer = QMessageBox.question(
            self, "Ирина Байкал · разрешение",
            f"Сайт:\n{site}\n\nЗапрашивает доступ: {name}.\nРазрешить?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if answer == QMessageBox.StandardButton.Yes:
            permission.grant()
        else:
            permission.deny()


class IrinaBrowser(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Ирина Байкал Браузер · PegiNelab")
        self.resize(1250, 830)
        self.setMinimumSize(730, 480)

        main = QWidget(self)
        layout = QVBoxLayout(main)
        layout.setSpacing(0)
        layout.setContentsMargins(0, 0, 0, 0)

        bar = QWidget()
        bar.setObjectName("topbar")
        tools = QHBoxLayout(bar)
        tools.setContentsMargins(12, 9, 12, 9)
        tools.setSpacing(7)

        self.back_btn = QPushButton("←")
        self.next_btn = QPushButton("→")
        self.reload_btn = QPushButton("⟳")
        self.home_btn = QPushButton("⌂")
        self.new_btn = QPushButton("+")
        self.brand = QPushButton("ИРИНА • БАЙКАЛ")
        self.brand.setObjectName("brand")
        self.address = QLineEdit()
        self.address.setPlaceholderText("Адрес сайта или поиск")
        self.address.returnPressed.connect(self.open_address)
        for item in (self.brand, self.back_btn, self.next_btn, self.reload_btn,
                     self.home_btn, self.address, self.new_btn):
            tools.addWidget(item, 1 if item is self.address else 0)

        self.tabs = QTabWidget()
        self.tabs.setDocumentMode(True)
        self.tabs.setTabsClosable(True)
        self.tabs.tabCloseRequested.connect(self.close_tab)
        self.tabs.currentChanged.connect(self.sync_ui)

        layout.addWidget(bar)
        layout.addWidget(self.tabs)
        self.setCentralWidget(main)
        self.setStyleSheet(STYLE)

        self.brand.clicked.connect(self.open_home)
        self.back_btn.clicked.connect(lambda: self.current() and self.current().back())
        self.next_btn.clicked.connect(lambda: self.current() and self.current().forward())
        self.reload_btn.clicked.connect(lambda: self.current() and self.current().reload())
        self.home_btn.clicked.connect(self.open_home)
        self.new_btn.clicked.connect(self.new_tab)

        for shortcut, action in (
            ("Ctrl+L", self.address.setFocus),
            ("Ctrl+T", self.new_tab),
            ("Ctrl+W", self.close_current_tab),
            ("Ctrl+R", lambda: self.current() and self.current().reload()),
            ("Alt+Left", lambda: self.current() and self.current().back()),
            ("Alt+Right", lambda: self.current() and self.current().forward()),
        ):
            qshort = QShortcut(QKeySequence(shortcut), self)
            qshort.activated.connect(action)

        self.new_tab()

    def current(self):
        return self.tabs.currentWidget()

    def new_tab(self, target=None):
        view = BrowserPage(self)
        index = self.tabs.addTab(view, "Новая вкладка")
        self.tabs.setCurrentIndex(index)
        view.titleChanged.connect(lambda title, v=view: self.set_tab_title(v, title))
        view.urlChanged.connect(lambda url, v=view: self.sync_url(v, url))
        view.loadFinished.connect(lambda _ok, v=view: self.update_navigation(v))
        view.setUrl(target if isinstance(target, QUrl) else START_URL)
        return view

    def set_tab_title(self, view, title):
        index = self.tabs.indexOf(view)
        if index >= 0:
            self.tabs.setTabText(index, (title or "Вкладка")[:28])

    def sync_url(self, view, url):
        if view is self.current():
            self.address.setText("" if url.isLocalFile() else url.toString())
            self.update_navigation(view)

    def update_navigation(self, view):
        if view is self.current():
            self.back_btn.setEnabled(view.history().canGoBack())
            self.next_btn.setEnabled(view.history().canGoForward())

    def sync_ui(self, _index):
        view = self.current()
        if view:
            self.sync_url(view, view.url())

    def open_address(self):
        value = address_to_url(self.address.text())
        view = self.current()
        if not view:
            view = self.new_tab()
        if value == "irina://home":
            view.setUrl(START_URL)
        else:
            view.setUrl(QUrl(value))

    def open_home(self):
        view = self.current() or self.new_tab()
        view.setUrl(START_URL)

    def close_current_tab(self):
        self.close_tab(self.tabs.currentIndex())

    def close_tab(self, index):
        if index < 0:
            return
        if self.tabs.count() == 1:
            self.open_home()
            return
        view = self.tabs.widget(index)
        self.tabs.removeTab(index)
        view.deleteLater()


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Ирина Байкал Браузер")
    window = IrinaBrowser()
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
