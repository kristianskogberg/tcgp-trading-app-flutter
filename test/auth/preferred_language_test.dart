import 'package:flutter_test/flutter_test.dart';
import 'package:tcgp_trading_app/auth/preferred_language.dart';

void main() {
  test('a profile with a specific language prefers it', () {
    expect(preferredLanguageOf({'preferred_language': 'JPN'}), 'JPN');
  });

  test('an unset, "any language" or unknown value is no preference', () {
    expect(preferredLanguageOf(null), isNull);
    expect(preferredLanguageOf({}), isNull);
    expect(preferredLanguageOf({'preferred_language': null}), isNull);
    expect(preferredLanguageOf({'preferred_language': 'ANY'}), isNull);
    expect(preferredLanguageOf({'preferred_language': 'XYZ'}), isNull);
    expect(preferredLanguageOf({'preferred_language': 3}), isNull);
  });
}
