import 'package:flutter_test/flutter_test.dart';
import 'package:splitcheck/core/utils/number_parser.dart';

void main() {
  test('Spoken numbers become digits', () {
    final cases = {
      'ten': 10.0, 'Ten.': 10.0, 'twenty five': 25.0, 'twenty-five': 25.0, 'ten dirhams': 10.0,
      'AED 15': 15.0, '15 percent': 15.0, 'twelve point five': 12.5, '12.5': 12.5, '12,5': 12.5,
      'a hundred': 100.0, 'one hundred and twenty': 120.0, '١٥': 15.0, 'عشرة': 10.0,
      'خمسة وعشرين': 25.0, 'خمسة عشر': 15.0, 'خمستاشر': 15.0, 'مية وخمسين': 150.0,
      'واحد وعشرين': 21.0, 'عشرين درهم': 20.0,
    };
    cases.forEach((k, v) => expect(parseSpokenNumber(k), v, reason: k));
    expect(parseSpokenNumber('hello'), isNull);
  });
}
