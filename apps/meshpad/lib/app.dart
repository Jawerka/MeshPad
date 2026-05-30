import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/meshpad_theme.dart';
import 'features/shell/app_shell.dart';

class MeshPadApp extends ConsumerWidget {
  const MeshPadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      home: const AppShell(),
    );
  }
}

Future<void> bootstrapMeshPadApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
}
