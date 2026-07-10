import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/ui/status_hint_provider.dart';

void main() {
  test('status hint show replaces previous and dismiss clears', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(statusHintProvider.notifier);
    notifier.show('first');
    expect(container.read(statusHintProvider)?.message, 'first');

    notifier.show('second');
    expect(container.read(statusHintProvider)?.message, 'second');

    notifier.dismiss();
    expect(container.read(statusHintProvider), isNull);
  });

  test('error hints use longer default duration', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(statusHintProvider.notifier).show(
          'failed',
          severity: StatusHintSeverity.error,
        );
    expect(
      container.read(statusHintProvider)?.duration,
      const Duration(seconds: 6),
    );
  });
}
