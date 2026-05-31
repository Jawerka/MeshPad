import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'core/storage/app_settings_store.dart';
import 'core/theme/meshpad_theme.dart';
import 'features/shell/app_shell.dart';
import 'platform/background_sync.dart';
import 'platform/desktop_shell.dart';
import 'platform/share_intent_listener.dart';

class MeshPadApp extends ConsumerStatefulWidget {
  const MeshPadApp({super.key});

  @override
  ConsumerState<MeshPadApp> createState() => _MeshPadAppState();
}

class _MeshPadAppState extends ConsumerState<MeshPadApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(DesktopShell.instance.destroyTray());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(DesktopShell.instance.destroyTray());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshPad',
      debugShowCheckedModeBanner: false,
      theme: MeshPadTheme.dark(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ShareIntentListener(child: AppShell()),
    );
  }
}

Future<void> bootstrapMeshPadApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }
  await initDesktopShell();
  await BackgroundSyncRegistrar.initialize();
  final settingsStore = AppSettingsStore();
  final settings = await settingsStore.loadSettings();
  final dataDir = p.normalize(
    settings.dataDir ?? await settingsStore.defaultDataDir(),
  );
  MeshPadLog.configure(logFilePath: p.join(dataDir, 'meshpad.log'));
  await BackgroundSyncRegistrar.applySettings(settings);
  await initializeDateFormatting('ru');
}
