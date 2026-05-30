import 'package:flutter/material.dart';

/// Root shell — Sprint 2 will replace with chat feed from ref/.
class MeshPadApp extends StatelessWidget {
  const MeshPadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshPad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          surface: const Color(0xFF0f1419),
          primary: const Color(0xFF6b9fff),
        ),
        scaffoldBackgroundColor: const Color(0xFF0f1419),
        useMaterial3: true,
      ),
      locale: const Locale('ru'),
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MeshPad')),
      body: const Center(
        child: Text(
          'Лента заметок — в разработке (Спринт 2).\n'
          'См. ref/ и PLAN.md.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
