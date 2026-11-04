// End-to-end tests of the chat flow, driven through the controller.
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitcheck/core/services/providers.dart';
import 'package:splitcheck/features/flow/chat_message.dart';
import 'package:splitcheck/features/flow/flow_controller.dart';

void main() {
  late ProviderContainer c;
  FlowController ctl() => c.read(chatProvider.notifier);

  /// Waits until the bot has finished "typing" and nothing changed for a bit.
  Future<void> settle() async {
    var last = -1;
    while (true) {
      await Future.delayed(const Duration(milliseconds: 600));
      final n = c.read(chatProvider).length;
      if (n == last && !c.read(isTypingProvider)) return;
      last = n;
    }
  }

  Future<void> say(String text) async { await ctl().handleInput(text); await settle(); }

  Future<void> tap(String label) async {
    final msgs = c.read(chatProvider);
    for (final m in msgs.reversed) {
      final chip = m.chips?.where((x) => x.label == label && !x.used).firstOrNull;
      if (chip != null) { ctl().chipTapped(m, chip); await settle(); return; }
    }
    fail('No active chip "$label". Last bot message: ${msgs.lastWhere((m) => m.role == MessageRole.bot).text}');
  }

  String lastBot() => c.read(chatProvider).lastWhere((m) => m.role == MessageRole.bot).text;
  String id(String name) => c.read(billDraftProvider).people.firstWhere((p) => p.name == name).id;

  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('splitcheck').path));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    c = ProviderContainer();
    c.listen(chatProvider, (_, __) {}); // keep alive
  });
  tearDown(() => c.dispose());

  test('full flow with edit-who, typed tip and fixed discount', () async {
    await settle();
    expect(lastBot(), contains('How many persons will split the check?'));
    expect(lastBot(), isNot(contains(r'${')));

    await tap('2');
    await say('Ahmed, Sara');
    expect(lastBot(), contains('Ahmed, Sara'));
    await tap('Yep 👍');

    await say('2');
    await say('Burger');
    await say('40');
    expect(c.read(flowStepProvider), FlowStep.itemWho);
    await ctl().confirmSelectedPeople([id('Ahmed')]);
    await settle();
    await say('Pizza');
    await say('60');
    await say('everyone');
    expect(c.read(flowStepProvider), FlowStep.itemSummary);

    // Edit "who had it" on Burger → must UPDATE, not add a new item.
    await tap('Edit an item');
    await tap('Burger · \$40.00');
    await tap('Who Ordered This Order ?');
    expect(c.read(flowStepProvider), FlowStep.itemWho);
    await ctl().confirmSelectedPeople([id('Sara')]);
    await settle();
    final items = c.read(billDraftProvider).items;
    expect(items.length, 2);
    expect(items.first.personIds, [id('Sara')]);

    await tap('Looks good 👍');
    await tap('None');            // VAT
    await tap('10%');             // service
    await say('5');               // typed tip → goes on to delivery, then discount
    expect(c.read(flowStepProvider), FlowStep.delivery);
    await tap('Yes');
    expect(lastBot(), contains('How much is the delivery fee'));
    await say('10');
    expect(c.read(billDraftProvider).extras.deliveryFee, 10);
    expect(c.read(flowStepProvider), FlowStep.discount);

    await tap('Fixed amount');
    await say('50');              // ≤ 100 but explicitly a FIXED amount
    final ex = c.read(billDraftProvider).extras;
    expect(ex.discountFixed, 50);
    expect(ex.discountPct, 0);
    expect(c.read(flowStepProvider), FlowStep.confirm);
    expect(lastBot(), contains('Discount'));
    expect(lastBot(), contains('Delivery'));

    await tap('Split it ✨');
    final r = c.read(splitResultProvider)!;
    // (100 - 50) = 50, +10% service +5% tip = 57.50, + delivery 10 = 67.50
    expect(r.grandTotal, closeTo(67.5, 0.001));
    final sum = r.personResults.fold(0.0, (a, p) => a + p.total);
    expect(sum, closeTo(67.5, 0.001));
    expect(r.personResults.every((p) => (p.deliveryShare - 5).abs() < 1e-9), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('ambiguous discount asks % or amount; edit from summary returns to summary', () async {
    await settle();
    await say('1');
    await say('Omar');
    await tap('Yep 👍');
    await say('1');
    await say('Tea');
    await say('20');
    await say('Omar');
    await tap('Looks good 👍');
    await tap('None');
    await tap('None');
    await tap('No tip');
    await tap('No');              // no delivery
    await say('10');
    expect(lastBot(), contains('percentage or an amount'));
    await tap('10% off');
    expect(c.read(billDraftProvider).extras.discountPct, 10);
    expect(c.read(flowStepProvider), FlowStep.confirm);

    // Change VAT from the final summary → straight back to the summary.
    await tap('Change something');
    await tap('VAT');
    await tap('5%');
    expect(c.read(flowStepProvider), FlowStep.confirm);
    expect(c.read(billDraftProvider).extras.vatPct, 5);
    expect(c.read(billDraftProvider).extras.discountPct, 10); // untouched
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('quantity, typed portions, VAT already included, place name, recent group', () async {
    await settle();
    await tap('2');
    await say('Mona, Karim');
    await tap('Yep 👍');
    await say('1');
    await say('Pizza');
    expect(lastBot(), contains('2x15'));          // quantity hint on the first price
    await say('3x10');                           // 3 slices × 10
    expect(c.read(flowStepProvider), FlowStep.itemWho);
    await ctl().handleInput('Mona 2, Karim');    // typed portions
    await settle();
    final it = c.read(billDraftProvider).items.single;
    expect(it.price, 30);
    expect(it.quantity, 3);
    expect(it.portions, {id('Mona'): 2});
    expect(lastBot(), contains('Mona ×2'));

    await tap('Looks good 👍');
    await tap('Already in prices');              // VAT included → nothing added
    expect(c.read(billDraftProvider).extras.vatPct, 0);
    await tap('None');                           // service
    await tap('No tip');
    await tap('No');                             // delivery
    await tap('Nope');                           // discount
    await tap('🏷 Add place name');
    await say('Pizza Roma');
    expect(c.read(billDraftProvider).merchant, 'Pizza Roma');
    expect(lastBot(), contains('🏷 Pizza Roma'));
    await tap('Split it ✨');
    final r = c.read(splitResultProvider)!;
    expect(r.personResults.firstWhere((x) => x.person.name == 'Mona').total, 20);
    expect(r.personResults.firstWhere((x) => x.person.name == 'Karim').total, 10);

    // Next bill offers the same group as a one-tap button.
    await ctl().reset();
    await settle();
    await tap('2');
    expect(lastBot(), contains('group from last time'));
    await tap('Mona, Karim');
    expect(c.read(billDraftProvider).people.map((p) => p.name), ['Mona', 'Karim']);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
