import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('meshPadExceptionUserMessage maps network errors', () {
    expect(
      meshPadExceptionUserMessage(
        const SyncTransportException('offline'),
      ),
      'offline',
    );
    expect(
      meshPadExceptionUserMessage(Exception('SocketException: failed')),
      'Нет подключения к сети',
    );
  });
}
