import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/utils/trust_score.dart';

void main() {
  test('public trust score displays exact values through 200', () {
    expect(formatPublicTrustScore(0), '0');
    expect(formatPublicTrustScore(195), '195');
    expect(formatPublicTrustScore(200), '200');
  });

  test('public trust score displays 200+ above the public ceiling', () {
    expect(formatPublicTrustScore(201), '200+');
    expect(formatPublicTrustScore(205), '200+');
    expect(formatPublicTrustScore(235), '200+');
  });
}
