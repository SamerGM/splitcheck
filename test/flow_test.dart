// End-to-end tests of the chat flow, driven through the controller.
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitcheck/core/services/providers.dart';
import 'package:splitcheck/core/services/settings_provider.dart';
import 'package:splitcheck/core/utils/countries.dart';
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    c = ProviderContainer();
    await c.read(groupsProvider.notifier).init();   // opens the settings store
    await c.read(currencyProvider.notifier).init();
    c.listen(chatProvider, (_, __) {}); // keep alive
  });

  /// Welcome → skip country → names typed in the chat → confirm → (no group).
  Future<void> startWith(String names) async {
    await settle();
    await tap('Skip');
    await say(names);
    await tap('Yep 👍');
    if (lastBot().contains('as a group')) await tap('No thanks');
  }
  tearDown(() => c.dispose());

  test('full flow with edit-who, typed tip, delivery and fixed discount', () async {
    await settle();
    expect(lastBot(), contains('preferred country or currency'));
    expect(lastBot(), isNot(contains(r'${')));
    await tap('Skip');
    expect(c.read(flowStepProvider), FlowStep.people);
    await say('Ahmed, Sara');
    expect(lastBot(), contains('Ahmed, Sara'));
    await tap('Yep 👍');
    expect(lastBot(), contains('as a group'));       // offers to save new names
    await tap('No thanks');

    await tap('2');                                  // item-count button
    await tap('🍔 Burger');                          // name suggestion
    expect(c.read(flowStepProvider), FlowStep.itemPrice);
    await say('40');
    expect(c.read(flowStepProvider), FlowStep.itemWho);
    await ctl().confirmSelectedPeople([id('Ahmed')]);
    await settle();
    expect(lastBot(), isNot(contains('Burger')));     // used suggestions disappear
    await say('Pizza');
    await say('60');
    await say('everyone');
    expect(c.read(flowStepProvider), FlowStep.itemSummary);

    // Edit "who had it" on Burger → must UPDATE, not add a new item.
    await tap('Edit an item');
    await tap(r'Burger · $40.00');
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
    await say('10');
    expect(c.read(flowStepProvider), FlowStep.discount);

    await tap('Fixed amount');
    await say('50');              // ≤ 100 but explicitly a FIXED amount
    final ex = c.read(billDraftProvider).extras;
    expect(ex.discountFixed, 50);
    expect(ex.discountPct, 0);
    expect(c.read(flowStepProvider), FlowStep.roundUp);
    expect(lastBot(), contains('never down'));
    await tap('No');              // no rounding
    expect(c.read(flowStepProvider), FlowStep.confirm);
    expect(lastBot(), contains('Discount'));
    expect(lastBot(), contains('Delivery'));

    await tap('Split it ✨');
    final r = c.read(splitResultProvider)!;
    // (100 - 50) = 50, +10% service +5% tip = 57.50, + delivery 10 = 67.50
    expect(r.grandTotal, closeTo(67.5, 0.001));
    final sum = r.personResults.fold(0.0, (a, p) => a + p.total);
    expect(sum, closeTo(67.5, 0.001));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('country: choose → make default → not asked next time; Settings keeps it', () async {
    await settle();
    await tap('🌍 Choose country');                       // the screen would open the list
    expect(c.read(sheetRequestProvider)?.$1, SheetRequest.country);
    await ctl().countryChosen(countryByCode('EG')!);
    await settle();
    expect(c.read(currencyProvider), 'EGP');
    expect(lastBot(), contains('default'));
    await tap('Yes, save it');
    expect(lastBot(), contains('Who’s splitting'));
    expect(c.read(currencyProvider.notifier).hasDefault, isTrue);

    await ctl().reset();
    await settle();
    expect(c.read(chatProvider).any((m) => m.text.contains('preferred country')), isFalse);
    expect(c.read(flowStepProvider), FlowStep.people);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('people sheet: empty names → Person 1, 2…; save as group; group button next time', () async {
    await settle();
    await tap('Skip');
    await ctl().peopleFromSheet(['Mona', '', '']);
    await settle();
    expect(c.read(billDraftProvider).people.map((p) => p.name), ['Mona', 'Person 2', 'Person 3']);
    await tap('💾 Save group');
    await say('Work friends');
    expect(c.read(groupsProvider).single.name, 'Work friends');
    expect(c.read(flowStepProvider), FlowStep.itemCount);

    await ctl().reset();
    await settle();
    await tap('Skip');
    await tap('👥 Work friends');                   // one tap, no "save group" question again
    expect(c.read(billDraftProvider).people.map((p) => p.name), ['Mona', 'Person 2', 'Person 3']);
    expect(c.read(flowStepProvider), FlowStep.itemCount);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('quantity, typed portions, VAT already included, place name, round up to 5', () async {
    await startWith('Mona, Karim');
    await tap('1');
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

    await tap('Looks good 👍');
    await tap('Already in prices');              // VAT included → nothing added
    expect(c.read(billDraftProvider).extras.vatPct, 0);
    await tap('None');                           // service
    await tap('No tip');
    await tap('No');                             // delivery
    await tap('Nope');                           // discount
    await tap('Up to 5');                        // round up
    await tap('🏷 Add place name');
    await say('Pizza Roma');
    expect(lastBot(), contains('🏷 Pizza Roma'));
    await tap('Split it ✨');
    final r = c.read(splitResultProvider)!;
    expect(r.personResults.firstWhere((x) => x.person.name == 'Mona').total, 20);   // 20 → 20
    expect(r.personResults.firstWhere((x) => x.person.name == 'Karim').total, 10);  // 10 → 10
    expect(r.roundingExtra, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('undo takes back answers step by step, including the final split', () async {
    await startWith('Nour, Ali');
    await say('1');
    await say('Tea');
    expect(c.read(flowStepProvider), FlowStep.itemPrice);

    ctl().undo();                                   // takes back "Tea"
    expect(c.read(flowStepProvider), FlowStep.itemName);
    expect(lastBot(), contains('Item 1 of 1'));

    ctl().undo();                                   // takes back "1"
    expect(c.read(flowStepProvider), FlowStep.itemCount);

    await say('1'); await say('Coffee'); await say('12');
    await ctl().handleInput('everyone'); await settle();
    await tap('Looks good 👍'); await tap('None'); await tap('None');
    await tap('No tip'); await tap('No'); await tap('Nope'); await tap('No');
    await tap('Split it ✨');
    expect(c.read(splitResultProvider), isNotNull);

    ctl().undo();                                   // takes back "Split it"
    expect(c.read(splitResultProvider), isNull);
    expect(c.read(flowStepProvider), FlowStep.confirm);
    await tap('Split it ✨');
    expect(c.read(splitResultProvider)!.grandTotal, 12);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
