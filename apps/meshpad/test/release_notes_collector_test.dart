import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/services/release_notes_collector.dart';

void main() {
  group('compareAppVersions', () {
    test('orders semver parts', () {
      expect(compareAppVersions('0.3.0', '0.2.9'), greaterThan(0));
      expect(compareAppVersions('0.2.0', '0.2.0'), 0);
      expect(compareAppVersions('1.0.0', '0.9.9'), greaterThan(0));
    });

    test('ignores build metadata suffix', () {
      expect(compareAppVersions('0.2.6+1', '0.2.6'), 0);
    });
  });

  group('collectReleaseNotesMarkdown', () {
    final releases = [
      {
        'tag_name': 'v0.2.6',
        'prerelease': false,
        'draft': false,
        'body': '### Added\n- Hub deploy',
      },
      {
        'tag_name': 'v0.2.5',
        'prerelease': false,
        'draft': false,
        'body': '### Added\n- LAN hub',
      },
      {
        'tag_name': 'v0.2.4',
        'prerelease': false,
        'draft': false,
        'body': '### Fixed\n- Sync bug',
      },
      {
        'tag_name': 'v0.2.3-rc1',
        'prerelease': true,
        'draft': false,
        'body': 'Should be skipped',
      },
    ];

    test('collects multiple versions between current and latest', () {
      final notes = collectReleaseNotesMarkdown(
        releases: releases,
        currentVersion: '0.2.4',
        latestVersion: '0.2.6',
      );

      expect(notes, isNotNull);
      expect(notes, contains('## v0.2.6'));
      expect(notes, contains('## v0.2.5'));
      expect(notes, isNot(contains('## v0.2.4')));
      expect(notes, isNot(contains('Should be skipped')));
      expect(
        notes!.indexOf('## v0.2.6'),
        lessThan(notes.indexOf('## v0.2.5')),
      );
    });

    test('returns null when no release bodies in range', () {
      final notes = collectReleaseNotesMarkdown(
        releases: [
          {
            'tag_name': 'v0.2.6',
            'prerelease': false,
            'draft': false,
            'body': '',
          },
        ],
        currentVersion: '0.2.5',
        latestVersion: '0.2.6',
      );

      expect(notes, isNull);
    });

    test('skips auto-generated compare-only bodies', () {
      final notes = collectReleaseNotesMarkdown(
        releases: [
          {
            'tag_name': 'v0.2.6',
            'prerelease': false,
            'draft': false,
            'body':
                '**Full Changelog**: https://github.com/Jawerka/MeshPad/compare/v0.2.5...v0.2.6',
          },
        ],
        currentVersion: '0.2.5',
        latestVersion: '0.2.6',
      );

      expect(notes, isNull);
    });
  });
}
