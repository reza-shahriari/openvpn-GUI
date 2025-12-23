#!/usr/bin/env python3
"""
OpenVPN Manager - A modern PySide2/QML application for managing OpenVPN connections
"""
import sys
import os
from PySide2.QtWidgets import QApplication
from PySide2.QtQml import qmlRegisterType, QQmlApplicationEngine
from PySide2.QtCore import QObject, Signal, Property, QUrl

from vpn_manager import VPNManager


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("OpenVPN Manager")
    app.setOrganizationName("VPN Manager")
    
    # Register VPNManager as a QML type
    qmlRegisterType(VPNManager, "VPNManager", 1, 0, "VPNManager")
    
    engine = QQmlApplicationEngine()
    engine.load(QUrl.fromLocalFile(os.path.join(os.path.dirname(__file__), "main.qml")))
    
    if not engine.rootObjects():
        sys.exit(-1)
    
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()


