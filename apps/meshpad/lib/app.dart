import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'core/l10n/app_locale.dart';
import 'core/providers/discovery_providers.dart';
import 'core/providers/notes_providers.dart';
import 'core/storage/app_settings.dart';
import 'core/storage/app_settings_store.dart';
import 'core/theme/meshpad_theme.dart';
import 'core/theme/meshpad_theme_scope.dart';
import 'core/ui/status_hint_host.dart';
import 'features/shell/app_shell.dart';
import 'l10n/app_localizations.dart';
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
    } else if (state == AppLifecycleState.resumed && !kIsWeb) {
      unawaited(ref.read(discoveryServiceProvider).refresh());
    }
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final themeMode = settingsAsync.maybeWhen(
      data: (s) => s.themeMode,
      orElse: () => AppThemeMode.dark,
    );
    final localeMode = settingsAsync.maybeWhen(
      data: (s) => s.localeMode,
      orElse: () => AppLocaleMode.ru,
    );
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final overlayBrightness = effectiveBrightness(
      mode: themeMode,
      platformBrightness: platformBrightness,
    );
    final isDark = overlayBrightness == Brightness.dark;

    if (!kIsWeb && Platform.isAndroid) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    }

    return MaterialApp(
      title: 'MeshPad',
      debugShowCheckedModeBanner: false,
      theme: MeshPadTheme.light(),
      darkTheme: MeshPadTheme.dark(),
      themeMode: toMaterialThemeMode(themeMode),
      locale: resolveAppLocale(localeMode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        return MeshPadThemeScope(
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  bottom: false,
                  child: StatusHintHost(),
                ),
              ),
            ],
          ),
        );
      },
      home: const ShareIntentListener(child: AppShell()),
    );
  }
}

Future<void> bootstrapMeshPadApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
    return;
  }
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
  SyncClockMonitor.onAnomaly = (message) => MeshPadLog.warn('sync', message);
  await BackgroundSyncRegistrar.applySettings(settings);
  await initializeDateFormatting('ru');
  await initializeDateFormatting('en');
}
