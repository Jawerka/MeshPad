import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/constants/app_info.dart';

void main() {
  test('kAppVersion matches apps/meshpad/pubspec.yaml', () {
    final pubspec = File('pubspec.yaml');
    expect(pubspec.existsSync(), isTrue);
    final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
        .firstMatch(pubspec.readAsStringSync());
    expect(match, isNotNull);
    expect(kAppVersion, match!.group(1));
  });
}
