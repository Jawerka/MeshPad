import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop tray + minimize-to-tray (Windows/Linux, Sprint 5).
class DesktopShell with TrayListener, WindowListener {
  DesktopShell._();
  static final DesktopShell instance = DesktopShell._();

  VoidCallback? onShowWindow;
  Future<void> Function()? onSync;

  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  Future<void> init() async {
    if (!isSupported) return;

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/icons/tray_icon.ico'
          : 'assets/icons/tray_icon.ico',
    );
    await trayManager.setToolTip('MeshPad');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Открыть MeshPad'),
          MenuItem(key: 'sync', label: 'Синхронизировать'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: 'Выход'),
        ],
      ),
    );
    trayManager.addListener(this);
  }

  Future<void> showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideToTray() async {
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    showMainWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showMainWindow();
      case 'sync':
        onSync?.call();
      case 'exit':
        trayManager.destroy();
        exit(0);
    }
  }

  @override
  void onWindowClose() {
    hideToTray();
  }

  Future<void> dispose() async {
    if (!isSupported) return;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }
}

Future<void> initDesktopShell({
  Future<void> Function()? onSync,
}) async {
  if (!DesktopShell.isSupported) return;
  DesktopShell.instance.onSync = onSync;
  await DesktopShell.instance.init();
}

Future<void> showDesktopWindow() => DesktopShell.instance.showMainWindow();
