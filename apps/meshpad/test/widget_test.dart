import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad/core/models/notes_feed_state.dart';
import 'package:meshpad/core/providers/notes_providers.dart';
import 'package:meshpad/features/shell/app_shell.dart';

class _EmptyNotesListNotifier extends NotesListNotifier {
  @override
  Future<NotesFeedState> build() async => const NotesFeedState();
}

void main() {
  testWidgets('desktop shell shows trash in header', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesListProvider.overrideWith(_EmptyNotesListNotifier.new),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('mobile feed shows trash and sync in header', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesListProvider.overrideWith(_EmptyNotesListNotifier.new),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });
}
