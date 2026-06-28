import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('gitHttpsAuthConfigArgs returns empty for blank token', () {
    expect(gitHttpsAuthConfigArgs(''), isEmpty);
    expect(gitHttpsAuthConfigArgs('   '), isEmpty);
  });

  test('gitHttpsAuthConfigArgs builds bearer extraheader', () {
    expect(
      gitHttpsAuthConfigArgs('gho_test'),
      ['-c', 'http.extraheader=AUTHORIZATION: bearer gho_test'],
    );
  });
}
