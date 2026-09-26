import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/constants/nz_locations.dart';

void main() {
  group('NzLocations.standardizeDisplayLocation', () {
    test('normalizes translated Auckland labels to English', () {
      expect(NzLocations.standardizeDisplayLocation('奥克兰'), 'Auckland');
      expect(NzLocations.standardizeDisplayLocation('奥克兰市中心'), 'Auckland CBD');
    });

    test('does not expose legacy coordinate labels', () {
      final label = NzLocations.standardizeDisplayLocation(
        'Approx. -36.85, 174.76',
        latitude: -36.85,
        longitude: 174.76,
      );

      expect(label, isNot(contains('-36.85')));
      expect(label, isNot(contains('174.76')));
      expect(label, anyOf('Auckland', 'Auckland CBD'));
    });

    test('canonicalizes common Auckland variants', () {
      expect(
        NzLocations.standardizeDisplayLocation('Auckland Central'),
        'Auckland CBD',
      );
      expect(
        NzLocations.standardizeDisplayLocation('Auckland CBD, Auckland'),
        'Auckland CBD',
      );
    });
  });
}
