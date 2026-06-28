import 'package:meshpad_server/note_change_hub.dart';
import 'package:test/test.dart';

void main() {
  test('eventsAfter returns only newer ids', () {
    final hub = NoteChangeHub();
    hub.noteCreated('a');
    hub.noteUpdated('b');
    hub.feedChanged();

    expect(hub.eventsAfter(null), isEmpty);
    expect(hub.eventsAfter(0), hasLength(3));
    expect(hub.eventsAfter(1), hasLength(2));
    expect(hub.eventsAfter(2), hasLength(1));
    expect(hub.eventsAfter(3), isEmpty);

    hub.dispose();
  });

  test('history is capped at maxHistory', () {
    final hub = NoteChangeHub();
    for (var i = 0; i < NoteChangeHub.maxHistory + 10; i++) {
      hub.feedChanged();
    }
    final afterZero = hub.eventsAfter(0);
    expect(afterZero.length, lessThanOrEqualTo(NoteChangeHub.maxHistory));
    hub.dispose();
  });
}
