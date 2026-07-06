import 'dart:io';

import 'package:meshpad_server/hub/hub_info.dart';
import 'package:test/test.dart';

void main() {
  test('kHubVersion matches apps/meshpad/pubspec.yaml', () {
    final pubspec = File('../../apps/meshpad/pubspec.yaml');
    expect(pubspec.existsSync(), isTrue);
    final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
        .firstMatch(pubspec.readAsStringSync());
    expect(match, isNotNull);
    expect(kHubVersion, match!.group(1));
  });
}
