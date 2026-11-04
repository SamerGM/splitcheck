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

  // ── People ─────────────────────────────────────────────────────────────────
  String get welcome => _t('Hey there 👋 Let’s split this bill.', 'أهلاً 👋 يلا نقسم الفاتورة.');
  String get howManyPeople => _t('How many of you are there?', 'كم شخص سيتم تقسيم الفاتورة عليهم؟');
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
  String get namesExample => _t('e.g. Ahmed, Sara, Omar', 'مثلاً: جمال، سارة، هاني');
  String gotIt(String names) => _t('Got it — $names', 'تمام — $names');
  String countMismatch(int expected, int got) => _t(
      'Heads up: you said $expected people but I count $got.',
      'خد بالك: قلت ${toArabicDigits('$expected')} أشخاص بس أنا عدّيت ${toArabicDigits('$got')}.');
  String get isCorrect => _t('All right?', 'كده تمام؟');
  String get yes => _t('Yep 👍', 'نعم 👍');
  String get noReenter => _t('Start over', 'من الأول');
  String get addMoreNames => _t('Add more', 'أضف أسماء أكثر');
  String get typeMoreNames => _t('Who else is in?', 'مين كمان؟');
  String get peopleConfirmed => _t('Sweet, everyone’s in ✓', 'حلو، كلّه موجود ✓');
  String get namesNotFound => _t(
      'Hmm, I didn’t catch any names. Try: Ahmed, Sara, Omar',
      'مش لاقي أسماء 🤔 جرّب كده: جمال، سارة، هاني');
  String get typeNamesAgain => _t('No worries — type the names again.', 'ولا يهمك — اكتب الأسماء تاني.');
  String reenterPeople(String current) => _t(
      'Sure. Type the full list of names.\nRight now: $current',
      'أكيد. اكتب كل الأسماء.\nدلوقتي: $current');

  // ── Items ──────────────────────────────────────────────────────────────────
  String get howManyItems => _t('How many items are on the bill?', 'كام صنف في الفاتورة؟');
  String get howManyMoreItems => _t('How many more?', 'كام صنف كمان؟');
  String get scanTip => _t('Or tap 📷 to scan the receipt.', 'أو دوس 📷 وصوّر الفاتورة.');
  String itemNamePrompt(int current, int total) => _t(
      'Item $current of $total — what is it?',
      'الصنف ${toArabicDigits('$current')} من ${toArabicDigits('$total')} — إيه هو؟');
  String itemPricePrompt(String name) => _t('How much was the $name?', '$name بكام؟');
  String itemWhoPrompt(String name, String price) => _t('Who had the $name ($price)?', 'مين أخد $name ($price)؟');
  String itemExists(String name) => _t(
      '“$name” is already on the list — call it something else?',
      '«$name» موجود قبل كده — سمّيه اسم تاني؟');
  String namesNotOnBill(String names, String valid) => _t(
      'I don’t know “$names” 🤔\nPick from: $valid',
      'مش عارف «$names» 🤔\nاختار من: $valid');
  String get selectAtLeastOne => _t('Pick at least one person.', 'اختار شخص واحد على الأقل.');
  String itemConfirmed(String name, String price, String who) => '✓ $name · $price → $who';
  String get everyoneLower => _t('everyone', 'الكل');
  String get noItemsYet => _t('No items yet — let’s add some.', 'مفيش أصناف لسه — يلا نضيف.');
  String allItemsAdded(String subtotal) => _t('Here’s what we’ve got — $subtotal', 'ده اللي عندنا — $subtotal');
  String get looksGood => _t('Looks good 👍', 'تمام 👍');
  String get addMoreItemsBtn => _t('Add more', 'ضيف أصناف');
  String get editExistingItem => _t('Edit an item', 'عدّل صنف');
  String get whichItemToEdit => _t('Which one?', 'أنهي صنف؟');
  String get back => _t('Back', 'رجوع');
  String whatToChangeInItem(String name) => _t('What should I change on $name?', 'عايز تغيّر إيه في $name؟');
  String get editName => _t('Name', 'الاسم');
  String get editPrice => _t('Price', 'السعر');
  String get editWhoOrdered => _t('Who had it', 'مين أخده');
  String get deleteItem => _t('Delete', 'امسح');
  String get enterNewName => _t('What’s the new name?', 'إيه الاسم الجديد؟');
  String get enterNewPrice => _t('What’s the new price?', 'السعر الجديد كام؟');
  String itemRemoved(String item) => _t('Removed $item 🗑', 'اتمسح $item 🗑');
  String itemUpdated(String item) => _t('Updated $item ✓', 'اتعدّل $item ✓');
  String itemsCount(int n) => _t('$n item${n == 1 ? '' : 's'}', _arCount(n, 'صنف', 'صنفين', 'أصناف'));
  String get pleaseEnterValidNumber => _t('Hmm, that doesn’t look like a number. Try again?', 'ده مش رقم 🤔 جرّب تاني؟');
  String get tapAButton => _t('Just tap one of the buttons above 👆', 'دوس على زرار من اللي فوق 👆');

  // ── Scanning ───────────────────────────────────────────────────────────────
  String get scanning => _t('📷 Scanning receipt…', '📷 بقرا الفاتورة…');
  String get arabicReceiptDetected => _t(
      'Looks like an Arabic receipt — I can’t read those yet. Let’s type the items instead.',
      'الفاتورة دي بالعربي ولسه مش بعرف أقراها. يلا نكتب الأصناف.');
  String scannedItems(int n) => _t(
      'Found $n items ✨ They’re shared by everyone for now — use “Edit an item” to change who had what.',
      'لقيت ${toArabicDigits('$n')} أصناف ✨ دلوقتي متقسمة على الكل — استخدم «عدّل صنف» عشان تغيّر مين أخد إيه.');
  String get cantReadReceipt => _t('Couldn’t read any items 😕 Try a clearer photo.', 'مقدرتش أقرا حاجة 😕 جرّب صورة أوضح.');
  String get cantScanReceipt => _t(
      'Scanning didn’t work. Try another photo or type the items.',
      'المسح منفعش. جرّب صورة تانية أو اكتب الأصناف.');
  String get scanReceiptTitle => _t('Scan receipt', 'صوّر الفاتورة');
  String get takePhoto => _t('Take photo', 'صوّر دلوقتي');
  String get chooseGallery => _t('Choose from library', 'اختار من الصور');

  // ── VAT / service / tip ────────────────────────────────────────────────────
  String get custom => _t('Other', 'نسبة تانية');
  String get typeValidPct => _t('Type a percentage between 0 and 100.', 'اكتب نسبة من ٠ لـ ١٠٠.');
  String get vatQuestion => _t('Any VAT on the bill?', 'فيه ضريبة على الفاتورة؟');
  String get noVatChip => _t('None', 'لأ');
  String get typeVat => _t('Type the VAT % (e.g. 7)', 'اكتب نسبة الضريبة (مثلاً ١٤)');
  String get noVat => _t('No VAT ✓', 'من غير ضريبة ✓');
  String vatApplied(String pct) => _t('VAT $pct ✓', 'ضريبة $pct ✓');
  String get serviceQuestion => _t('Service charge?', 'فيه خدمة؟');
  String get noServiceChip => _t('None', 'لأ');
  String get typeService => _t('Type the service %', 'اكتب نسبة الخدمة');
  String get noService => _t('No service charge ✓', 'من غير خدمة ✓');
  String serviceApplied(String pct) => _t('Service $pct ✓', 'خدمة $pct ✓');
  String get tipQuestion => _t('Leaving a tip? 💸', 'هتسيب بقشيش؟ 💸');
  String get noTipChip => _t('No tip', 'لأ');
  String get typeTip => _t('Type the tip %', 'اكتب نسبة البقشيش');
  String get noTip => _t('No tip ✓', 'من غير بقشيش ✓');
  String tipApplied(String pct) => _t('Tip $pct ✓', 'بقشيش $pct ✓');

  // ── Discount ───────────────────────────────────────────────────────────────
  String get discountQuestion => _t('Got a discount or voucher? 🎟', 'فيه خصم أو كوبون؟ 🎟');
  String get noDiscount => _t('Nope', 'لأ');
  String get percentDiscount => _t('% off', 'نسبة ٪');
  String get fixedDiscount => _t('Fixed amount', 'مبلغ ثابت');
  String get enterDiscountPct => _t('How many % off?', 'الخصم كام في المية؟');
  String get enterDiscountFixed => _t('How much off?', 'الخصم كام؟');
  String get discountWhichKind => _t('Is that a percentage or an amount?', 'نسبة ولا مبلغ؟');
  String discountPctOption(String pct) => _t('$pct off', 'خصم $pct');
  String discountFixedOption(String amt) => _t('$amt off', 'خصم $amt');
  String discountPctApplied(String pct) => _t('$pct off ✓', 'خصم $pct ✓');
  String discountFixedApplied(String amt) => _t('$amt off ✓', 'خصم $amt ✓');
  String discountCapped(String amt) => _t(
      'That’s more than the bill 😅 Capped the discount at $amt.',
      'الخصم أكبر من الفاتورة 😅 خليته $amt.');
  String get noDiscountApplied => _t('No discount ✓', 'من غير خصم ✓');

  // ── Final confirm ──────────────────────────────────────────────────────────
  String get finalConfirmTitle => _t('Quick check before I do the math:', 'مراجعة سريعة قبل ما أحسب:');
  String get subtotalLabel => _t('Subtotal', 'المجموع');
  String get discountLabel => _t('Discount', 'الخصم');
  String get vatLabel => _t('VAT', 'الضريبة');
  String get serviceLabel => _t('Service', 'الخدمة');
  String get tipLabel => _t('Tip', 'البقشيش');
  String get grandTotal => _t('Total', 'الإجمالي');
  String get calculate => _t('Split it ✨', 'قسّمها ✨');
  String get editBtn => _t('Change something', 'عدّل');
  String get tapCalculate => _t('Tap “Split it” when you’re ready, or “Change something”.', 'دوس «قسّمها» لما تبقى جاهز، أو «عدّل».');
  String get whatToEdit => _t('What do you want to change?', 'عايز تعدّل إيه؟');
  String get editPeople => _t('People', 'الأشخاص');
  String get editItems => _t('Items', 'الأصناف');
  String get editNumberOfItems => _t('Redo all items', 'دخّل الأصناف من الأول');

  // ── Result ─────────────────────────────────────────────────────────────────
  String get finalSplit => _t('Done! Here’s who owes what 🎉', 'خلصنا! ده نصيب كل واحد 🎉');
  String get billDone => _t('All split! Tap “New bill” to start another.', 'اتقسمت! دوس «فاتورة جديدة» عشان تبدأ.');
  String get perPerson => _t('Per person', 'لكل شخص');
  String get breakdown => _t('Breakdown', 'التفاصيل');
  String get copy => _t('Copy', 'نسخ');
  String get share => _t('Share', 'مشاركة');
  String get newBill => _t('New bill', 'فاتورة جديدة');
  String get copied => _t('Copied to clipboard', 'اتنسخ');
  String get shareFooter => _t('Split with SplitCheck', 'تم التقسيم عبر SplitCheck');
  String get billWord => _t('Bill split', 'تقسيم الفاتورة');
  String get sharedTag => _t('shared', 'مشترك');

  // ── UI chrome ──────────────────────────────────────────────────────────────
  String get typeHint => _t('Message', 'اكتب رسالة');
  String get listening => _t('Listening…', 'سامعك…');
  String get iHeard => _t('Did I get that right?', 'ده اللي سمعته؟');
  String get tryAgain => _t('Try again', 'جرّب تاني');
  String get send => _t('Send', 'إرسال');
  String get couldntHear => _t('Couldn’t hear you — try again or just type it.', 'مسمعتكش — جرّب تاني أو اكتب.');
  String get selectPeople => _t('Who had it?', 'مين أخده؟');
  String get everyone => _t('Everyone', 'الكل');
  String get confirm => _t('Done', 'تم');
  String get settings => _t('Settings', 'الإعدادات');
  String get currency => _t('Currency', 'العملة');
  String get language => _t('Language', 'اللغة');
  String get appearance => _t('Appearance', 'المظهر');
  String get light => _t('Light', 'فاتح');
  String get dark => _t('Dark', 'داكن');
  String get auto => _t('Auto', 'تلقائي');
  String get startOver => _t('Start over', 'ابدأ من جديد');
  String get startOverConfirm => _t('This clears the current bill.', 'ده هيمسح الفاتورة الحالية.');
  String get cancel => _t('Cancel', 'إلغاء');
  String get done => _t('Done', 'تم');
}
