import 'package:meshpad_api_client/meshpad_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('parseSseEventStream', () {
    test('parses data lines', () async {
      final events = await parseSseEventStream(
        Stream.fromIterable([
          ': connected',
          'data: {"type":"note_created","note_id":"abc"}',
          '',
        ]),
      ).toList();

      expect(events, hasLength(1));
      expect(events.single.type, 'note_created');
      expect(events.single.noteId, 'abc');
    });

    test('parses id field before data', () async {
      final events = await parseSseEventStream(
        Stream.fromIterable([
          'id: 42',
          'data: {"type":"note_updated","note_id":"n1"}',
          '',
        ]),
      ).toList();

      expect(events.single.id, 42);
      expect(events.single.type, 'note_updated');
      expect(events.single.noteId, 'n1');
    });

    test('ignores comment lines', () async {
      final events = await parseSseEventStream(
        Stream.fromIterable([
          ': keep-alive',
          'data: {"type":"feed_changed"}',
        ]),
      ).toList();

      expect(events.single.type, 'feed_changed');
      expect(events.single.noteId, isNull);
    });
  });
}
