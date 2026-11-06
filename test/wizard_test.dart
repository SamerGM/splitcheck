// Tests of the full-screen page flow, driven through the wizard controller.
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitcheck/core/services/providers.dart';
import 'package:splitcheck/core/services/settings_provider.dart';
import 'package:splitcheck/core/utils/countries.dart';
import 'package:splitcheck/features/wizard/wizard_controller.dart';

void main() {
  late ProviderContainer c;
  WizardController w() => c.read(wizardProvider.notifier);
  WStep step() => c.read(wizardProvider).step;
  String id(String name) => c.read(billDraftProvider).people.firstWhere((p) => p.name == name).id;

  setUpAll(() => Hive.init(Directory.systemTemp.createTempSync('splitcheck').path));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    c = ProviderContainer();
    await c.read(groupsProvider.notifier).init();   // opens the settings store
    await c.read(currencyProvider.notifier).init();
    await c.read(myNameProvider.notifier).init();
  });
  tearDown(() => c.dispose());

  test('dine-in in Egypt: full flow, usual rates, totals add up', () async {
    expect(step(), WStep.orderType);
    w().chooseOrderType(delivery: false);
    expect(step(), WStep.country);
    w().pickCountry(countryByCode('EG')!);
    expect(step(), WStep.rates);
    expect(w().suggestedRates(), (14.0, 12.0));
    await w().confirmRates(vat: 14, service: 12, makeDefault: false);
    expect(c.read(currencyProvider), 'EGP');
    expect(step(), WStep.peopleCount);

    w().setPeopleCount(3);
    expect(w().pendingNames, ['', '', '']);
    w().confirmNames(['Samer', 'Ahmed', '']);        // empty → Person 3
    expect(c.read(billDraftProvider).people.map((p) => p.name), ['Samer', 'Ahmed', 'Person 3']);
    expect(step(), WStep.itemsMethod);

    w().chooseManual();
    w().setItemCount(2);
    expect(step(), WStep.itemEntry);
    final all = c.read(billDraftProvider).people.map((p) => p.id).toList();
    w().saveItem(0, name: 'Pizza', price: 300, whoIds: all);           // everyone
    expect(c.read(wizardProvider).nav.index, 1);
    w().saveItem(1, name: 'Drink', price: 60, whoIds: [id('Ahmed')]);  // one person
    expect(step(), WStep.itemsReview);
    expect(c.read(billDraftProvider).items.first.personIds, isEmpty); // everyone = shared

    w().itemsDone();
    expect(step(), WStep.tip);
    w().setTip(0);
    expect(step(), WStep.discount);                  // dine-in → no delivery page
    w().setDiscount();
    expect(step(), WStep.roundUp);
    w().setRoundUp(false);
    expect(step(), WStep.quickCheck);

    await w().splitIt();
    expect(step(), WStep.result);
    final r = c.read(splitResultProvider)!;
    // 360 + VAT 14% (50.40) + service 12% (43.20) = 453.60
    expect(r.grandTotal, closeTo(453.60, 0.001));
    expect(r.personResults.fold(0.0, (a, p) => a + p.total), closeTo(453.60, 0.001));
  });

  test('delivery: service 0 by default, delivery-fee page, whole numbers', () async {
    w().chooseOrderType(delivery: true);
    w().pickCountry(countryByCode('EG')!);
    expect(w().suggestedRates(), (14.0, 0.0));       // no service on delivery
    await w().confirmRates(vat: 14, service: 0, makeDefault: false);
    w().setPeopleCount(2);
    w().confirmNames(['A', 'B']);
    w().chooseManual();
    w().setItemCount(1);
    w().saveItem(0, name: 'Burger', price: 100.30, whoIds: [id('A'), id('B')]);
    w().itemsDone();
    w().setTip(0);
    expect(step(), WStep.delivery);
    w().setDelivery(20);
    w().setDiscount();
    w().setRoundUp(true);
    await w().splitIt();
    final r = c.read(splitResultProvider)!;
    // each: 50.15 * 1.14 + 10 = 67.171 → 68
    expect(r.personResults.map((p) => p.total), [68, 68]);
  });

  test('make default → next bill skips country & rates; Back goes back', () async {
    w().chooseOrderType(delivery: false);
    w().pickCountry(countryByCode('AE')!);
    await w().confirmRates(vat: 5, service: 10, makeDefault: true);
    expect(c.read(currencyProvider.notifier).hasDefault, isTrue);

    w().back();                                      // Back from people count → rates
    expect(step(), WStep.rates);

    w().startOver();
    w().chooseOrderType(delivery: false);
    expect(step(), WStep.peopleCount);               // country pages skipped
    expect(c.read(billDraftProvider).extras.vatPct, 5);
    expect(c.read(billDraftProvider).extras.servicePct, 10);
  });

  test('Quick check edits return to the Quick check; review edit/delete/add', () async {
    w().chooseOrderType(delivery: false);
    w().skipCountry();
    w().setPeopleCount(2);
    w().confirmNames(['Nour', 'Ali']);
    w().chooseManual();
    w().setItemCount(2);
    final all = c.read(billDraftProvider).people.map((p) => p.id).toList();
    w().saveItem(0, name: 'Tea', price: 10, whoIds: all);
    w().saveItem(1, name: 'Cake', price: 20, whoIds: all);
    // review: edit one item → back to review
    w().editItem(0);
    expect(c.read(wizardProvider).nav.single, isTrue);
    w().saveItem(0, name: 'Green tea', price: 12, whoIds: [id('Nour')]);
    expect(step(), WStep.itemsReview);
    expect(c.read(billDraftProvider).items.first.name, 'Green tea');
    w().deleteItem(1);
    w().addItem();
    w().saveItem(1, name: 'Water', price: 5, whoIds: all);
    expect(step(), WStep.itemsReview);
    expect(c.read(billDraftProvider).items.length, 2);

    w().itemsDone(); w().setTip(10); w().setDiscount(pct: 10); w().setRoundUp(false);
    expect(step(), WStep.quickCheck);

    // Edit people from the Quick check → straight back to it
    w().editPeople();
    expect(step(), WStep.names);
    w().confirmNames(['Nour', 'Ali', 'Omar']);
    expect(step(), WStep.quickCheck);
    expect(c.read(billDraftProvider).people.length, 3);

    // Edit items → review → Looks good → back to Quick check (not to Tip)
    w().editItems();
    w().itemsDone();
    expect(step(), WStep.quickCheck);

    // Edit charges → save → back
    w().editCharges();
    expect(step(), WStep.chargesEdit);
    w().saveCharges(c.read(billDraftProvider).extras.copyWith(tipPct: 0));
    expect(step(), WStep.quickCheck);
    expect(c.read(billDraftProvider).extras.tipPct, 0);
  });

  test('saved groups and "me" first', () async {
    await c.read(myNameProvider.notifier).set('Samer');
    w().chooseOrderType(delivery: false);
    w().skipCountry();
    w().setPeopleCount(3);
    expect(w().pendingNames, ['Samer', '', '']);
    await w().saveGroup('Club friends', ['Samer', 'Ahmed', '']);
    expect(c.read(groupsProvider).single.members, ['Samer', 'Ahmed', 'Person 3']);
    w().back();
    w().useGroup(c.read(groupsProvider).single);
    expect(w().pendingNames, ['Samer', 'Ahmed', 'Person 3']);
  });
}
