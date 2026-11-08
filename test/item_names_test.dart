import 'package:flutter_test/flutter_test.dart';
import 'package:splitcheck/core/models/models.dart';
import 'package:splitcheck/features/wizard/wizard_controller.dart';

void main() {
  test('Repeated items are numbered: Pizza, Pizza 2 → Pizza 1, Pizza 2', () {
    BillItem it(String n) => BillItem(id: n, name: n, price: 10);
    final out = numberRepeats([it('Pizza'), it('Cola'), it('Pizza 2'), it('pizza')]);
    expect(out.map((e) => e.name).toList(), ['Pizza 1', 'Cola', 'Pizza 2', 'Pizza 3']);
    expect(numberRepeats([it('بيتزا'), it('بيتزا ٢')], arabic: true).map((e) => e.name).toList(), ['بيتزا ١', 'بيتزا ٢']);
  });
}
