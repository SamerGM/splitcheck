import 'package:flutter_test/flutter_test.dart';
import 'package:splitcheck/core/utils/strings.dart';

void main() {
  const ar = S(true);
  test('Egyptian Arabic strings render with values filled in', () {
    expect(ar.howManyPeople, 'كم شخص سيتم تقسيم الفاتورة عليهم؟');
    expect(ar.peopleCountPrompt(2), 'تمام، شخصين. ما هي أسماؤهم؟');
    expect(ar.peopleCountPrompt(4), 'تمام، ٤ أشخاص. ما هي أسماؤهم؟');
    expect(ar.itemPricePrompt('كشري'), 'كشري بكام؟');
    expect(ar.itemNamePrompt(1, 3), 'الصنف ١ من ٣ — إيه هو؟');
    expect(ar.countMismatch(3, 2), 'خد بالك: قلت ٣ أشخاص بس أنا عدّيت ٢.');
    expect(ar.reenterPeople('جمال'), 'أكيد. اكتب كل الأسماء.\nدلوقتي: جمال');
    expect(ar.yes, 'نعم 👍');
  });

  test('No unfilled \${...} placeholders leak into any message', () {
    for (final s in [const S(false), ar]) {
      final samples = [
        s.welcome, s.howManyPeople, s.peopleCountPrompt(3), s.gotIt('A, B'),
        s.countMismatch(3, 2), s.itemNamePrompt(1, 2), s.itemPricePrompt('X'),
        s.itemWhoPrompt('X', 'AED 1.00'), s.itemExists('X'), s.namesNotOnBill('Z', 'A, B'),
        s.scannedItems(4), s.discountPctApplied('10%'), s.discountFixedApplied('AED 5.00'),
        s.discountCapped('AED 5.00'), s.whatToChangeInItem('X'), s.itemsCount(2),
      ];
      for (final t in samples) {
        expect(t.contains(r'${'), isFalse, reason: t);
        expect(t.contains(r'\'), isFalse, reason: t);
      }
    }
  });
}
