// lib/core/utils/strings.dart

/// Converts Western digits to Arabic-Indic digits for display.
String toArabicDigits(String input) {
  const western = '0123456789';
  const arabic  = '٠١٢٣٤٥٦٧٨٩';
  var result = input;
  for (int i = 0; i < 10; i++) {
    result = result.replaceAll(western[i], arabic[i]);
  }
  return result;
}

/// All user-facing text, English + Arabic. Tone: casual and friendly.
class S {
  final bool isAr;
  const S(this.isAr);

  String _t(String en, String ar) => isAr ? ar : en;

  // ── Number helpers ─────────────────────────────────────────────────────────
  String fmtNum(double n, {int decimals = 2}) {
    final str = n.toStringAsFixed(decimals);
    return isAr ? toArabicDigits(str) : str;
  }

  String fmtPct(double n) {
    final str = n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
    return isAr ? '${toArabicDigits(str)}٪' : '$str%';
  }

  String get appName => 'SplitCheck';

  /// Whole number in the current language's digits: 3 / ٣.
  String n(int v) => isAr ? toArabicDigits('$v') : '$v';
  /// "×2" / "×٢"
  String times(int v) => '×${n(v)}';
  /// "Cola ×2" / "كولا ×٢" (no suffix for a single item)
  String itemLabel(String name, int qty) => qty > 1 ? '$name ${times(qty)}' : name;

  // ── People ─────────────────────────────────────────────────────────────────
  String get welcome => _t('Hey there 👋 Let’s split this bill.', 'أهلاً 👋 يلا نقسم الفاتورة.');
  String get howManyPeople => _t('How many persons will split the check?', 'كم شخص سيتم تقسيم الفاتورة عليهم؟');
  String peopleCountPrompt(int n) => _t(
      'Nice, $n people. What are their names?',
      'تمام، ${_arCount(n, 'شخص', 'شخصين', 'أشخاص')}. ما هي أسماؤهم؟');

  /// Arabic counted noun: 1 → شخص واحد, 2 → شخصين, 3–10 → ٣ أشخاص, 11+ → ١١ شخص.
  static String _arCount(int n, String one, String two, String few) {
    if (n == 1) return '$one واحد';
    if (n == 2) return two;
    final d = toArabicDigits('$n');
    return n <= 10 ? '$d $few' : '$d $one';
  }
  String get namesExample => _t('ex. "James, Sara, Sam"', 'مثلاً: جمال، سارة، هاني');
  String gotIt(String names) => _t('Got it — $names', 'تمام — $names');
  String countMismatch(int expected, int got) => _t(
      'Heads up: you said $expected people but I count $got.',
      'خد بالك: قلت ${toArabicDigits('$expected')} أشخاص بس أنا عدّيت ${toArabicDigits('$got')}');
  String get isCorrect => _t('All right?', 'صح؟');
  String get yes => _t('Yep 👍', 'نعم 👍');
  String get noReenter => _t('Start over', 'نعيد الحساب من الأول');
  String get addMoreNames => _t('Add more', 'أضف أسماء أكثر');
  String get typeMoreNames => _t('Who else is in?', 'مين كمان؟');
  String get peopleConfirmed => _t('Looks Good, everyone’s in ✓', 'تمام، الكل موجود ✓');
  String get namesNotFound => _t(
      'Hmm, I didn’t catch any names. Try Names Like: James, Sara, Sam',
      'مش لاقي أسماء 🤔 جرّب كده: جمال، سارة، هاني');
  String get typeNamesAgain => _t('No worries — type the names again.', 'ولا يهمك — اكتب الأسماء تاني.');
  String reenterPeople(String current) => _t(
      'Sure. Type the full list of names.\nRight now: $current',
      'أكيد. اكتب كل الأسماء.\nالحالي: $current');

  // ── Items ──────────────────────────────────────────────────────────────────
  String get howManyItems => _t('How many items are there on the bill?', 'كم صنف في الفاتورة؟');
  String get howManyMoreItems => _t('How many more?', 'كم صنف زيادة؟');
  String get scanTip => _t('Or tap 📷 to scan the receipt.', 'أو اضغط 📷 لتصوير الفاتورة.');
  String itemNamePrompt(int current, int total) => _t(
      'Item $current of $total — what is it?',
      'الصنف ${toArabicDigits('$current')} من ${toArabicDigits('$total')} — ايه هو؟');
  String itemPricePrompt(String name) => _t('How much was the $name?', 'كام سعر $name؟');
  String itemWhoPrompt(String name, String price) => _t('Who had the $name ($price)?', 'مين طلب ال $name ($price)؟');
  String itemExists(String name) => _t(
      '“$name” is already on the list — call it something else?',
      '«$name» الاسم موجود قبل كدة — ممكن اسم ثاني؟');
  String namesNotOnBill(String names, String valid) => _t(
      'I don’t know “$names” 🤔\nPick from: $valid',
      'مش عارف «$names» 🤔\nاختر من: $valid');
  String get selectAtLeastOne => _t('Pick at least one person.', 'اختر شخص واحد على الأقل.');
  String itemConfirmed(String name, String price, String who) => '✓ $name · $price → $who';
  String get everyoneLower => _t('Everyone', 'الكل');
  String get noItemsYet => _t('No items yet — let’s add some.', 'مافيش أصناف لسه — يلا نضيف.');
  String allItemsAdded(String subtotal) => _t('Here’s what we’ve got — $subtotal', 'كدة تمام ؟ — $subtotal');
  String get looksGood => _t('Looks good 👍', 'تمام 👍');
  String get addMoreItemsBtn => _t('Add more', 'ضيف أصناف');
  String get editExistingItem => _t('Edit an item', 'عدّل صنف');
  String get whichItemToEdit => _t('Which one?', 'أي صنف؟');
  String get back => _t('Back', 'رجوع');
  String whatToChangeInItem(String name) => _t('What should I change on $name?', 'عايز تغيّر إيه في $name؟');
  String get editName => _t('Name', 'الاسم');
  String get editPrice => _t('Price', 'السعر');
  String get editWhoOrdered => _t('Who Ordered This Order ?', 'مين طلبه ؟');
  String get deleteItem => _t('Delete', 'مسح');
  String get enterNewName => _t('What’s the new name?', 'إيه الاسم الجديد؟');
  String get enterNewPrice => _t('What’s the new price?', 'كام السعر الجديد؟');
  String itemRemoved(String item) => _t('Removed $item 🗑', 'اتمسح $item 🗑');
  String itemUpdated(String item) => _t('Updated $item ✓', 'تم تعديل $item ✓');
  String itemsCount(int n) => _t('$n item(s)', _arCount(n, 'صنف', 'صنفين', 'أصناف'));
  String get pleaseEnterValidNumber => _t('Hmm, that doesn’t look like a number. Try again?', 'ده مش رقم 🤔 جرّب مرة ثانية؟');
  String get tapAButton => _t('Just tap one of the buttons above 👆', 'دوس على زرار من اللي فوق 👆');

  // ── Scanning ───────────────────────────────────────────────────────────────
  String get scanning => _t('📷 Scanning receipt…', '📷 جاري قراءة الفاتورة…');
  String get arabicReceiptDetected => _t(
      'Looks like an Arabic receipt — I can’t read those yet. Let’s type the items instead.',
      'الفاتورة دي بالعربي ولسة مش عارف أقراها. ممكن تكتب الأصناف.');
  String scannedItems(int n) => _t(
      'Found $n items ✨ They’re shared by everyone for now — use “Edit an item” to change who had which order.',
      'لقيت ${toArabicDigits('$n')} أصناف ✨ حالياً مقسومة على الكل — استخدم «عدّل صنف» لتغيير مين طلب ايه.');
  String get cantReadReceipt => _t('Couldn’t read any items 😕 Try a clearer photo.', 'مقدرتش أقرا حاجة 😕 جرّب صورة أوضح.');
  String get cantScanReceipt => _t(
      'Scanning didn’t work. Try another photo or type the items.',
      'قراءة الصورة منفعتش. جرّب صورة تانية أو اكتب الأصناف.');
  String get scanReceiptTitle => _t('Scan receipt', 'تصوير الفاتورة');
  String get takePhoto => _t('Take photo', 'التقط صورة');
  String get chooseGallery => _t('Choose from library', 'اختر من الصور');

  // ── VAT / service / tip ────────────────────────────────────────────────────
  String get custom => _t('Other', 'غير');
  String get typeValidPct => _t('Type a percentage between 0 and 100.', 'اكتب نسبة من ٠ إلى ١٠٠.');
  String get vatQuestion => _t('shall we add VAT to the bill?', 'في ضريبة على الفاتورة؟');
  String get noVatChip => _t('None', 'لا');
  String get typeVat => _t('Type the VAT % (e.g. 7)', 'اكتب نسبة الضريبة (مثلاً ٧)');
  String get noVat => _t('No VAT ✓', 'بدون ضريبة ✓');
  String vatApplied(String pct) => _t('VAT $pct ✓', 'ضريبة $pct ✓');
  String get serviceQuestion => _t('Any Fixed Service charge?', 'في رسوم خدمة؟');
  String get noServiceChip => _t('None', 'لا');
  String get typeService => _t('Type the service %', 'اكتب نسبة الخدمة');
  String get noService => _t('No service charge ✓', 'بدون خدمة ✓');
  String serviceApplied(String pct) => _t('Service $pct ✓', 'خدمة $pct ✓');
  String get tipQuestion => _t('Leaving a tip? 💸', 'في بقشيش؟ 💸');
  String get noTipChip => _t('No tip', 'لا');
  String get typeTip => _t('Type the tip %', 'اكتب نسبة البقشيش');
  String get noTip => _t('No tip ✓', 'بدون بقشيش ✓');
  String tipApplied(String pct) => _t('Tip $pct ✓', 'بقشيش $pct ✓');

  // ── New features ───────────────────────────────────────────────────────────
  // Recent groups (names step)
  String get orPickRecent => _t('Or tap a group from last time 👇', 'أو اختار مجموعة من المرات اللي فاتت 👇');
  // Quantity
  String get priceQtyHint => _t('Ordered more than one? Type it like 2x15', 'طلبت أكتر من واحد؟ اكتب كده 2x15');
  String qtyConfirmed(int q, String unit, String total) => _t(
      '$q × $unit = $total', '${toArabicDigits('$q')} × $unit = $total');
  // Portions (people picker)
  String get portionsHint => _t('Someone had more? Use + to give them more portions.', 'حد أخد أكتر؟ دوس + عشان تزود نصيبه.');
  // Prices already include VAT / service
  String get alreadyIncluded => _t('Already in prices', 'محسوبة في الأسعار');
  String get vatIncludedApplied => _t('Got it — VAT is already in the prices, nothing added ✓', 'تمام — الضريبة محسوبة في الأسعار، مش هنضيف حاجة ✓');
  String get serviceIncludedApplied => _t('Got it — service is already in the prices, nothing added ✓', 'تمام — الخدمة محسوبة في الأسعار، مش هنضيف حاجة ✓');
  // Place name
  String get addPlaceName => _t('🏷 Add place name', '🏷 اسم المكان');
  String get askPlaceName => _t('What’s the place called?', 'اسم المكان إيه؟');
  String placeNameSaved(String name) => _t('Saved as “$name” ✓', 'اتسجل باسم «$name» ✓');
  String get placeLabel => _t('Place', 'المكان');
  // Rounding
  String get roundUp => _t('Round each share up', 'تقريب نصيب كل شخص لفوق');
  String get roundOff => _t('Off', 'لا');
  String get roundingLabel => _t('Rounded up', 'التقريب');
  // Per-person message
  String personMessage(String name, String amount, String place) => _t(
      'Hi $name 👋 Your share${place.isEmpty ? '' : ' for $place'} is $amount',
      'أهلاً $name 👋 نصيبك${place.isEmpty ? '' : ' في $place'} هو $amount');
  String get sendToPerson => _t('Send', 'إرسال');
  // History
  String get history => _t('History', 'السجل');
  String get historyEmpty => _t('No saved bills yet', 'لسه مفيش فواتير محفوظة');
  String get historyEmptyHint => _t('Bills you split will show up here.', 'الفواتير اللي بتقسمها هتظهر هنا.');
  String get untitledBill => _t('Bill', 'فاتورة');
  String get receiptPhoto => _t('Receipt photo', 'صورة الفاتورة');
  String peopleCount(int n) => _t('$n people', _arCount(n, 'شخص', 'شخصين', 'أشخاص'));
  String get today => _t('Today', 'النهارده');
  String get yesterday => _t('Yesterday', 'امبارح');

  // ── Undo ───────────────────────────────────────────────────────────────────
  String get undo => _t('Undo', 'الرجوع');
  String personN(int i) => _t('Person $i', 'شخص ${toArabicDigits('$i')}');

  // ── Welcome screen ─────────────────────────────────────────────────────────
  String get slogan => _t('Split the bill hassle-free\nand enjoy your outing 😉', 'قسّم الفاتورة من غير وجع دماغ\nواستمتع بخروجتك 😉');

  // ── Country / currency ─────────────────────────────────────────────────────
  String get askCountry => _t('Do you have a preferred country or currency?', 'عندك دولة أو عملة مفضلة؟');
  String get chooseCountry => _t('🌍 Choose country', '🌍 اختار الدولة');
  String get skip => _t('Skip', 'تخطي');
  String get countryCurrency => _t('Country & currency', 'الدولة والعملة');
  String get search => _t('Search', 'بحث');
  String currencySet(String country, String code) => _t('Currency: $country · $code ✓', 'العملة: $country · $code ✓');
  String get makeDefault => _t('Make it your default for next time?', 'تخليها الافتراضية للمرات الجاية؟');
  String get yesSaveIt => _t('Yes, save it', 'أيوه، احفظها');
  String get justThisTime => _t('Just this time', 'المرة دي بس');
  String get defaultSaved => _t('Saved as default ✓ You can change it anytime in Settings ⚙️', 'اتحفظت كافتراضية ✓ تقدر تغيّرها في أي وقت من الإعدادات ⚙️');

  // ── People sheet ───────────────────────────────────────────────────────────
  String get askPeople => _t(
      'Who’s splitting the bill? Add the names — or leave them empty for Person 1, Person 2…',
      'مين هيقسم الفاتورة؟ اكتب الأسماء — أو سيبها فاضية وهتبقى شخص ١، شخص ٢…');
  String get addPeopleBtn => _t('👥 Add people', '👥 أضف الأشخاص');
  String get peopleTitle => _t('Add people', 'إضافة الأشخاص');
  String get numberOfPeople => _t('Number of people', 'عدد الأشخاص');
  String get includeMe => _t('Include me', 'ضيفني');
  String get yourName => _t('Your name', 'اسمك');
  String get addPerson => _t('Add person', 'إضافة شخص');
  String get yourGroups => _t('Your groups', 'مجموعاتك');
  String get saveAsGroup => _t('Save as a group', 'احفظهم كمجموعة');
  String get groupNameHint => _t('Group name (e.g. Work friends)', 'اسم المجموعة (مثلاً: أصحاب الشغل)');

  // ── Friend groups (chat + settings) ────────────────────────────────────────
  String saveGroupQuestion(String names) => _t('Save $names as a group for next time?', 'تحفظ $names كمجموعة للمرات الجاية؟');
  String get saveGroupBtn => _t('💾 Save group', '💾 احفظ المجموعة');
  String get noThanks => _t('No thanks', 'لا شكراً');
  String get askGroupName => _t('What should I call this group?', 'تحب تسمي المجموعة إيه؟');
  String groupSaved(String name) => _t('Group “$name” saved ✓', 'اتحفظت مجموعة «$name» ✓');
  String get friendGroups => _t('Saved groups', 'المجموعات المحفوظة');
  // Saved groups: actions, editor, settings
  String get useThisGroup => _t('Use this group', 'استخدم المجموعة دي');
  String get editGroup => _t('Edit group', 'تعديل المجموعة');
  String get deleteGroup => _t('Delete group', 'حذف المجموعة');
  String get newGroup => _t('New group', 'مجموعة جديدة');
  String get addSavedGroup => _t('Add saved group', 'إضافة مجموعة محفوظة');
  String get groupName => _t('Group name', 'اسم المجموعة');
  String get members => _t('Members', 'الأعضاء');
  String get addMember => _t('Add member', 'إضافة عضو');
  String get memberHint => _t('Name', 'الاسم');
  String get delete => _t('Delete', 'حذف');
  String deleteGroupQ(String name) => _t('Delete “$name”?', 'حذف «$name»؟');
  String get deleteGroupNote => _t('The group is removed. Past bills are kept.', 'هتتحذف المجموعة. الفواتير القديمة هتفضل موجودة.');
  String get savedGroupsFooter => _t('Saved groups appear in “How many people?” and “Who’s splitting?”.',
      'المجموعات المحفوظة بتظهر في «كام شخص؟» و«مين بيقسم؟».');
  String get holdForOptions => _t('Press and hold a group for more options', 'اضغط مطوّلاً على المجموعة لخيارات أكتر');
  String get allAlreadyAdded => _t('Everyone in this group is already in the list', 'كل اللي في المجموعة موجودين بالفعل');
  String addedFromGroup(int n) => _t('Added $n from the group', 'اتضاف ${toArabicDigits('$n')} من المجموعة');
  String get noGroupsYet => _t('No groups yet — they’re saved after you add people.', 'لسه مفيش مجموعات — بتتحفظ بعد ما تضيف الأشخاص.');

  // ── Items ──────────────────────────────────────────────────────────────────
  String get typeItemCount => _t('Type the number of items', 'اكتب عدد الأصناف');
  /// Quick name suggestions for the item-name step.
  List<String> get itemSuggestions => isAr
      ? const ['🍕 بيتزا', '🍝 باستا', '🍔 برجر', '🍗 طبق فراخ', '🥩 طبق لحمة', '🥗 سلطة', '🍟 بطاطس', '🥤 مشروب', '☕ قهوة', '🧃 عصير', '🍰 حلو']
      : const ['🍕 Pizza', '🍝 Pasta', '🍔 Burger', '🍗 Chicken plate', '🥩 Beef plate', '🥗 Salad', '🍟 Fries', '🥤 Drink', '☕ Coffee', '🧃 Juice', '🍰 Dessert'];

  // ── Round each share up (asked in the chat) ────────────────────────────────
  String get roundUpQuestion => _t(
      'Round each share up? 💵\nEveryone pays a round number — easier for cash.\nExample: 37.72 → 38 (with 1) or 40 (with 5).\nIt only goes up, never down.',
      'تقرّب نصيب كل واحد لفوق؟ 💵\nكل واحد يدفع رقم صحيح — أسهل في الكاش.\nمثال: ٣٧٫٧٢ ← ٣٨ (مع ١) أو ٤٠ (مع ٥).\nبيقرّب لفوق بس، عمره ما ينقص.');
  String get roundNo => _t('No', 'لا');
  String roundTo(int v) => _t('Up to $v', 'لأقرب ${toArabicDigits('$v')}');
  String roundApplied(int v) => _t('Rounding each share up to $v ✓', 'هنقرّب نصيب كل واحد لأقرب ${toArabicDigits('$v')} ✓');
  String get noRounding => _t('No rounding ✓', 'بدون تقريب ✓');
  String get roundingMenu => _t('Rounding', 'التقريب');

  // ── Full-screen pages ──────────────────────────────────────────────────────
  String get continueBtn => _t('Continue', 'متابعة');
  String stepOf(int n, int total) => _t('Step $n of $total', 'الخطوة ${toArabicDigits('$n')} من ${toArabicDigits('$total')}');
  String get nextItem => _t('Next item →', 'الصنف التالي ←');
  String get saveBtn => _t('Save', 'حفظ');
  String get otherNumber => _t('Other number…', 'رقم تاني…');

  // Order type
  String get whereEat => _t('Where did you eat?', 'أكلتوا فين؟');
  String get dineIn => _t('Dine-in', 'في المطعم');
  String get dineInHint => _t('Restaurant or café — usually with service charge', 'مطعم أو كافيه — غالباً فيه خدمة');
  String get deliveryOrder => _t('Delivery', 'دليفري');
  String get deliveryOrderHint => _t('Ordered online — with a delivery fee', 'طلب أونلاين — فيه رسوم توصيل');

  // Prices final?
  String get pricesFinalQ => _t('Are the menu prices final?', 'أسعار المنيو نهائية؟');
  String get pricesFinalHint => _t('Do they already include VAT/Tax and service charge?', 'هل تشمل الضريبة ورسوم الخدمة؟');
  String get vatWillBeAdded => _t('VAT/Tax will be added to the bill', 'الضريبة هتتضاف على الفاتورة');
  String get vatWillBeAddedHint => _t('Menu prices + VAT/Tax and service', 'أسعار المنيو + الضريبة والخدمة');
  String get pricesAreFinal => _t('Prices are final — don’t add VAT/Tax', 'الأسعار نهائية — متضيفش ضريبة');
  String get pricesAreFinalHint => _t('You pay exactly what the menu says', 'هتدفع نفس اللي في المنيو بالظبط');
  String get vatBadge => _t('+VAT', '+ضريبة');
  String get vatAndService => _t('VAT & service', 'الضريبة والخدمة');
  String get includedInPrices => _t('Included in prices', 'شاملة في الأسعار');
  String get pricesIncludeToggle => _t('Prices already include VAT & service', 'الأسعار شاملة الضريبة والخدمة');

  // Country & rates
  String get countryHint => _t('Sets the currency and the usual VAT & service', 'بتحدد العملة والضريبة والخدمة المعتادة');
  String get searchCountry => _t('Search country or currency', 'دوّر على دولة أو عملة');
  String get skipUseUsd => _t('Skip — use US Dollar', 'تخطي — استخدم الدولار');
  String usualRates(String country) => _t('Usual rates in $country — tap a box to edit', 'المعتاد في $country — دوس على الخانة للتعديل');
  String get serviceCharge => _t('Service charge', 'رسوم الخدمة');
  String get makeMyDefault => _t('⭐ Make it my default', '⭐ خليها الافتراضية');
  String get thisBillOnly => _t('Use for this bill only', 'للفاتورة دي بس');
  String get defaultNote => _t('Default = skip this step next time. Change it anytime in ⚙️ Settings.',
      'الافتراضية = مش هنسألك تاني. تقدر تغيّرها في أي وقت من ⚙️ الإعدادات.');
  String get defaultCountry => _t('Default country & currency', 'الدولة والعملة الافتراضية');
  String get noDefaultCountry => _t('Not set — asked on each bill', 'مش محددة — بنسأل كل فاتورة');

  // People
  String get howManyPeopleTitle => _t('How many people?', 'كام شخص؟');
  String get includingYou => _t('Including you', 'وأنت معاهم');
  String get orPickGroup => _t('Or pick a saved group', 'أو اختار مجموعة محفوظة');
  String get whoSplitting => _t('Who’s splitting?', 'مين بيقسم؟');
  String get namesHint => _t('Type names, use 🎤 or pick from contacts 📇 · empty = Person 1, 2…',
      'اكتب الأسماء أو استخدم 🎤 أو اختار من جهات الاتصال 📇 · الفاضي = شخص ١، ٢…');
  String get meTag => _t('me', 'أنا');
  String get meDefault => _t('Me', 'أنا');
  String get includeMeHint => _t('Are you splitting this bill too?', 'وأنت كمان هتقسم معاهم؟');
  String get saveAsGroupBtn => _t('💾 Save as group', '💾 احفظهم كمجموعة');
  String get nameThisGroup => _t('Name this group', 'سمّي المجموعة');
  List<String> get groupSuggestions => isAr
      ? const ['⚽ أصحاب النادي', '💼 الشغل', '👨‍👩‍👧 العيلة', '🎓 أصحاب الجامعة', '🏠 الجيران', '🏋️ أصحاب الجيم']
      : const ['⚽ Club friends', '💼 Work group', '👨‍👩‍👧 Family', '🎓 Uni friends', '🏠 Neighbours', '🏋️ Gym buddies'];

  // Items
  String get addTheItems => _t('Add the items', 'أضف الأصناف');
  String get howAddItems => _t('How do you want to add what you ordered?', 'تحب تضيف الطلبات إزاي؟');
  String get scanReceiptOpt => _t('Scan receipt', 'صوّر الفاتورة');
  String get scanReceiptHint => _t('Take a photo — I read the items and prices', 'صوّرها وأنا أقرأ الأصناف والأسعار');
  String get enterManually => _t('Enter manually', 'أدخلها بنفسك');
  String get enterManuallyHint => _t('Type each item, one by one', 'اكتب كل صنف لوحده');
  String get howManyItemsTitle => _t('How many items?', 'كام صنف؟');
  String get itemsCountHint => _t('Each different dish or drink on the bill', 'كل طبق أو مشروب مختلف في الفاتورة');
  String itemXofY(int i, int n) => _t('Item $i of $n', 'الصنف ${toArabicDigits('$i')} من ${toArabicDigits('$n')}');
  String get whatOrdered => _t('What did you order?', 'طلبتوا إيه؟');
  String get priceLabel => _t('Price', 'السعر');
  String get whoShared => _t('Who shared it?', 'مين شارك فيه؟');
  String splitBetween(String names, String each) => _t('Split between $names · $each each', 'متقسم على $names · $each لكل واحد');
  String get fillItem => _t('Add a name, a price and who shared it', 'اكتب الاسم والسعر ومين شارك فيه');
  String get yourItems => _t('Your items', 'أصنافك');
  String itemsTotal(int n, String amt) => _t('$n item${n == 1 ? '' : 's'} · $amt', '${toArabicDigits('$n')} أصناف · $amt');
  String get editSmall => _t('✏️ Edit', '✏️ تعديل');
  String get deleteSmall => _t('🗑 Delete', '🗑 حذف');
  String get addItemBtn => _t('+ Add item', '+ أضف صنف');
  String get looksGoodNext => _t('Looks good →', 'تمام ←');

  // Charges
  String get tipHint => _t('Shared by what each person ordered', 'بيتقسم حسب طلب كل واحد');
  String get noneOpt => _t('None', 'لا');
  String get otherPct => _t('Other %…', 'نسبة تانية…');
  String get deliveryTitle => _t('Delivery fee 🛵', 'رسوم التوصيل 🛵');
  String get deliveryEqualHint => _t('Split equally — everyone gets the same delivery', 'بتتقسم بالتساوي — التوصيل للكل');
  String get noDeliveryFee => _t('No delivery fee', 'مفيش رسوم توصيل');
  String get percentage => _t('% Percentage', '٪ نسبة');
  String get applyBtn => _t('Apply', 'تطبيق');
  String get noDiscountBtn => _t('No discount', 'مفيش خصم');
  String get wholeTitle => _t('Make everyone’s share a whole number?', 'تخلي نصيب كل واحد رقم صحيح؟');
  String get wholeHint => _t('No decimals, easier to pay.\nExample: 10.03 → 11', 'من غير كسور، أسهل في الدفع.\nمثال: ١٠٫٠٣ ← ١١');
  String get yesRoundUp => _t('Yes, round up', 'أيوه، قرّب لفوق');
  String get wholeNumbers => _t('Whole numbers', 'أرقام صحيحة');
  String get onLabel => _t('On', 'مفعّل');
  String get offLabel => _t('Off', 'مقفول');
  String get editCharges => _t('Edit charges', 'تعديل الرسوم');

  // Quick check
  String get quickCheckTitle => _t('Quick check', 'مراجعة سريعة');
  String peopleSection(int n) => _t('People · $n', 'الأشخاص · ${toArabicDigits('$n')}');
  String itemsSection(int n) => _t('Items · $n', 'الأصناف · ${toArabicDigits('$n')}');
  String get chargesSection => _t('Charges', 'الرسوم');

  // ── Delivery ───────────────────────────────────────────────────────────────
  String get deliveryQuestion => _t('Any delivery fee? 🛵', 'في رسوم توصيل؟ 🛵');
  String get deliveryYes => _t('Yes', 'نعم');
  String get deliveryNo => _t('No', 'لا');
  String get enterDelivery => _t('How much is the delivery fee?', 'كام رسوم التوصيل؟');
  String deliveryApplied(String amt) => _t('Delivery $amt ✓ (split equally)', 'توصيل $amt ✓ (بالتساوي على الكل)');
  String get noDelivery => _t('No delivery fee ✓', 'بدون توصيل ✓');
  String get deliveryLabel => _t('Delivery', 'التوصيل');

  // ── Discount ───────────────────────────────────────────────────────────────
  String get discountQuestion => _t('Got a discount or voucher? 🎟', 'في خصم أو قسيمة؟ 🎟');
  String get noDiscount => _t('Nope', 'لا');
  String get percentDiscount => _t('% off', 'نسبة ٪');
  String get fixedDiscount => _t('Fixed amount', 'مبلغ ثابت');
  String get enterDiscountPct => _t('How many % off?', 'كام نسبة الخصم؟');
  String get enterDiscountFixed => _t('How much off?', 'كام مبلغ الخصم؟');
  String get discountWhichKind => _t('Is that a percentage or an amount?', 'نسبة ولا مبلغ معين؟');
  String discountPctOption(String pct) => _t('$pct off', 'خصم $pct');
  String discountFixedOption(String amt) => _t('$amt off', 'خصم $amt');
  String discountPctApplied(String pct) => _t('$pct off ✓', 'خصم $pct ✓');
  String discountFixedApplied(String amt) => _t('$amt off ✓', 'خصم $amt ✓');
  String discountCapped(String amt) => _t(
      'That’s more than the bill 😅 Capped the discount at $amt.',
      'الخصم أكبر من الفاتورة 😅 خليته $amt.');
  String get noDiscountApplied => _t('No discount ✓', 'بدون خصم ✓');

  // ── Final confirm ──────────────────────────────────────────────────────────
  String get finalConfirmTitle => _t('Quick check before I do the math:', 'مراجعة سريعة قبل الحساب:');
  String get subtotalLabel => _t('Subtotal', 'المجموع');
  String get discountLabel => _t('Discount', 'الخصم');
  String get vatLabel => _t('VAT', 'الضريبة');
  String get serviceLabel => _t('Service', 'الخدمة');
  String get tipLabel => _t('Tip', 'البقشيش');
  String get grandTotal => _t('Total', 'الإجمالي');
  String get calculate => _t('Split it ✨', 'قسّمها ✨');
  String get editBtn => _t('Change something', 'عدّل');
  String get tapCalculate => _t('Tap “Split it” when you’re ready, or “Change something”.', 'اضغط «قسّمها» لما تكون جاهز، أو «عدّل».');
  String get whatToEdit => _t('What do you want to change?', 'محتاج تعدّل ايه؟');
  String get editPeople => _t('People', 'الأشخاص');
  String get editItems => _t('Items', 'الأصناف');
  String get editNumberOfItems => _t('Redo all items', 'عيد كل الأصناف');

  // ── Result ─────────────────────────────────────────────────────────────────
  String get finalSplit => _t('Done! Here’s your final required to pay amount 🎉', 'خلصنا! ده اجمالي حساب كل واحد 🎉');
  String get billDone => _t('All split! Tap “New bill” to start a new bill.', 'تم التقسيم! دوس علي «فاتورة جديدة» للبدء من الاول.');
  String get perPerson => _t('Per person', 'لكل شخص');
  String get breakdown => _t('Breakdown', 'التفاصيل');
  String get copy => _t('Copy', 'نسخ');
  String get share => _t('Share', 'مشاركة');
  String get newBill => _t('New bill', 'فاتورة جديدة');
  String get copied => _t('Copied to clipboard', 'تم النسخ');
  String get shareFooter => _t('Split with SplitCheck', 'تم التقسيم من خلال برنامج SplitCheck');
  String get billWord => _t('Bill split', 'تقسيم الفاتورة');
  String get sharedTag => _t('Shared', 'مشترك');
  // Shared text / card
  String get personsWord => _t('Persons', 'أشخاص');
  String get roundUpWord => _t('round-up', 'تقريب');
  String get roundUpRow => _t('Round-up', 'التقريب');
  String get deliveryFeeLabel => _t('Delivery fee', 'رسوم التوصيل');
  String get totalWord => _t('Total', 'الإجمالي');
  String get totalAfterVat => _t('Total after VAT', 'الإجمالي بعد الضريبة');
  String get itemsTotalLabel => _t('Items total', 'إجمالي الأصناف');
  String get grandTotalWord => _t('Grand total', 'الإجمالي النهائي');
  String get grandTotalAll => _t('Grand total after all additions + round-up', 'الإجمالي النهائي بعد كل الإضافات + التقريب');
  String get inclWord => _t('incl.', 'شامل');
  String get deliveryWord => _t('delivery', 'توصيل');
  String get tipWord => _t('tip', 'بقشيش');

  // ── UI chrome ──────────────────────────────────────────────────────────────
  String get typeHint => _t('Message', 'اكتب رسالة');
  String get listening => _t('Listening…', 'سامعك…');
  String get iHeard => _t('Did I get that right?', 'ده اللي سمعته؟');
  String get tryAgain => _t('Try again', 'جرب مرة ثانية');
  String get send => _t('Send', 'إرسال');
  String get couldntHear => _t('Couldn’t hear you — try again or just type it.', 'مسمعتكش — جرّب تاني أو اكتب.');
  String get selectPeople => _t('Who Ordered This Order ?', 'مين طلبه ؟');
  String get everyone => _t('Everyone', 'الكل');
  String get confirm => _t('Done', 'تمام');
  String get settings => _t('Settings', 'الإعدادات');
  String get currency => _t('Currency', 'العملة');
  String get language => _t('Language', 'اللغة');
  String get appearance => _t('Appearance', 'المظهر');
  String get light => _t('Light', 'فاتح');
  String get dark => _t('Dark', 'داكن');
  String get auto => _t('Auto', 'تلقائي');
  String get startOver => _t('Start over', 'ابدأ من جديد');
  String get startOverConfirm => _t('This clears the current bill.', 'هذا بيمسح بيانات الفاتورة الحالية.');
  String get cancel => _t('Cancel', 'إلغاء');
  String get done => _t('Done', 'تمام');
}
