import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/providers/notes_providers.dart';
import 'package:meshpad/features/shell/app_shell.dart';
import 'package:meshpad_core/meshpad_core.dart';

class _EmptyNotesListNotifier extends NotesListNotifier {
  @override
  Future<List<Note>> build() async => [];
}

void main() {
  testWidgets('feed shows trash FAB', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesListProvider.overrideWith(_EmptyNotesListNotifier.new),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    expect(find.text('MeshPad'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
