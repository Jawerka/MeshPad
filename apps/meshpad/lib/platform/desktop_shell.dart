import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop tray + minimize-to-tray (Windows/Linux).
class DesktopShell with TrayListener, WindowListener {
  DesktopShell._();
  static final DesktopShell instance = DesktopShell._();

  VoidCallback? onShowWindow;
  Future<void> Function()? onSync;
  var _trayInitialized = false;
  var _shuttingDown = false;

  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  Future<void> init() async {
    if (!isSupported) return;

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await trayManager.setIcon('assets/icons/tray_icon.ico');
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
    _trayInitialized = true;
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
    unawaited(showMainWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(showMainWindow());
      case 'sync':
        unawaited(onSync?.call());
      case 'exit':
        unawaited(shutdown());
    }
  }

  @override
  void onWindowClose() {
    unawaited(hideToTray());
  }

  /// Removes tray icon and closes the app. Must await native cleanup before exit.
  Future<void> shutdown() async {
    if (_shuttingDown) return;
    _shuttingDown = true;

    await destroyTray();
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {
      // Window may already be gone.
    }
    exit(0);
  }

  Future<void> destroyTray() async {
    if (!isSupported || !_trayInitialized) return;

    trayManager.removeListener(this);
    windowManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {
      // Tray may already be destroyed.
    }
    _trayInitialized = false;
  }

  Future<void> dispose() async {
    await destroyTray();
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

Future<void> shutdownDesktopShell() => DesktopShell.instance.shutdown();
