import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/models/notes_feed_state.dart';
import 'package:meshpad/core/providers/notes_providers.dart';
import 'package:meshpad/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _EmptyNotesListNotifier extends NotesListNotifier {
  @override
  Future<NotesFeedState> build() async => const NotesFeedState();
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
