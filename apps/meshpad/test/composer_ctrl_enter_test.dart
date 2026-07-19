import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/models/notes_feed_state.dart';
import 'package:meshpad/core/providers/notes_providers.dart';
import 'package:meshpad/core/services/notes_service.dart';
import 'package:meshpad/features/feed/feed_screen.dart';
import 'package:meshpad_core/meshpad_core.dart';

class _RecordingNotesListNotifier extends NotesListNotifier {
  static var createNoteCalls = 0;
  static String? lastMarkdown;

  @override
  Future<NotesFeedState> build() async => const NotesFeedState();

  @override
  Future<void> createNote({
    String title = '',
    required String markdown,
    List<String> attachmentPaths = const [],
    List<NoteAttachmentBytes> attachmentBytes = const [],
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    createNoteCalls++;
    lastMarkdown = markdown;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _RecordingNotesListNotifier.createNoteCalls = 0;
    _RecordingNotesListNotifier.lastMarkdown = null;
  });

  testWidgets('Ctrl+Enter in composer submits note', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesListProvider.overrideWith(_RecordingNotesListNotifier.new),
          isWebClientProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: FeedScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composerField = find.byType(TextField).first;
    expect(composerField, findsOneWidget);

    await tester.enterText(composerField, 'Hello sync');
    await tester.pump();

    await tester.tap(composerField);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(_RecordingNotesListNotifier.createNoteCalls, 1);
    expect(_RecordingNotesListNotifier.lastMarkdown, 'Hello sync');
  });
}
