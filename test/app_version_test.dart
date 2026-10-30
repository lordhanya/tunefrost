import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/core/utils/app_version.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('reads major, minor and patch as numbers', () {
      final version = AppVersion.tryParse('1.10.0');

      expect(version, isNotNull);
      expect(version!.major, 1);
      expect(version.minor, 10);
      expect(version.patch, 0);
      expect(version.toString(), '1.10.0');
    });

    test('ignores build numbers and pre-release tags', () {
      expect(AppVersion.tryParse('1.4.0+5'), const AppVersion(1, 4, 0));
      expect(AppVersion.tryParse('1.4.0-beta.1'), const AppVersion(1, 4, 0));
      expect(AppVersion.tryParse('  1.4.0  '), const AppVersion(1, 4, 0));
    });

    test('rejects anything that does not start with X.Y.Z', () {
      const bad = [
        '',
        '1.4',
        '1',
        '1.4.0.1',
        'v1.4.0',
        '1.4.x',
        'abc',
        'latest',
      ];

      for (final raw in bad) {
        expect(AppVersion.tryParse(raw), isNull, reason: '"$raw"');
      }
    });
  });

  group('AppVersion comparison', () {
    test('1.10.0 is newer than 1.2.0, not older as text would read it', () {
      final ten = AppVersion.tryParse('1.10.0')!;
      final two = AppVersion.tryParse('1.2.0')!;

      expect(ten > two, isTrue);
      expect(two < ten, isTrue);
      expect(ten.compareTo(two), greaterThan(0));
      // The bug this class exists to prevent: as strings '1.10.0' < '1.2.0'.
      expect('1.10.0'.compareTo('1.2.0'), lessThan(0));
    });

    test('orders by segment before segment', () {
      final list = [
        '2.0.0',
        '1.10.0',
        '1.2.0',
        '1.2.1',
        '1.9.9',
        '1.2.0',
      ].map((raw) => AppVersion.tryParse(raw)!).toList()..sort();

      expect(list.map((v) => v.toString()), [
        '1.2.0',
        '1.2.0',
        '1.2.1',
        '1.9.9',
        '1.10.0',
        '2.0.0',
      ]);
    });

    test('equality and hash follow the three segments', () {
      expect(AppVersion.tryParse('1.4.0+5'), const AppVersion(1, 4, 0));
      expect(
        AppVersion.tryParse('1.4.0+5').hashCode,
        const AppVersion(1, 4, 0).hashCode,
      );
      expect(const AppVersion(1, 4, 0) == const AppVersion(1, 4, 1), isFalse);
    });

    test('the comparison operators agree with compareTo', () {
      const a = AppVersion(1, 2, 3);
      const b = AppVersion(1, 2, 3);
      const c = AppVersion(1, 2, 4);

      expect(a <= b, isTrue);
      expect(a >= b, isTrue);
      expect(a < b, isFalse);
      expect(a > b, isFalse);
      expect(a < c, isTrue);
      expect(c > a, isTrue);
    });
  });
}
