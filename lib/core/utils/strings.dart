// lib/core/utils/strings.dart
// Convert Western digits to Arabic-Indic digits for display
String toArabicDigits(String input) {
  const western = '0123456789';
  const arabic  = '٠١٢٣٤٥٦٧٨٩';
  var result = input;
  for (int i = 0; i < 10; i++) {
    result = result.replaceAll(western[i], arabic[i]);
  }
  return result;
}

class S {
  final bool isAr;
  const S(this.isAr);

  String get appName => 'Split Check';

  // Step 1
  String get welcome => isAr ? '👋 أهلاً بك في Split Check!' : '👋 Welcome to Split Check!';
  String get step1Question => isAr ? 'الخطوة 1 — اكتب اسماء من سيتم تقسيم الفاتورة بينهم' : 'Step 1 — Who\'s splitting the bill?';
  String get typeOrSayNames => isAr ? 'اكتب أو قل جميع الأسماء دفعة واحدة.' : 'Type or say all names at once.';
  String get namesExample => isAr ? 'مثال: أحمد، سارة، عمر' : 'Example: Ahmed, Sara, Omar';
  String gotIt(String names) => isAr ? 'تم — $names' : 'Got it — $names';
  String get isCorrect => isAr ? 'هل هذا صحيح؟' : 'Is this correct?';
  String get yes => isAr ? 'نعم ✓' : 'Yes ✓';
  String get noReenter => isAr ? 'لا، أعد الإدخال' : 'No, re-enter';
  String get peopleConfirmed => isAr ? 'تم تأكيد الأشخاص ✓' : 'People confirmed ✓';
  String get namesNotFound => isAr ? 'لم أتمكن من العثور على أسماء. حاول كتابتها هكذا: أحمد، سارة، عمر' : 'I couldn\'t find any names. Try typing like: Ahmed, Sara, Omar';
  String get typeNamesAgain => isAr ? 'اكتب جميع الأسماء مرة أخرى.' : 'Type all names again.';
  String get addMoreNames => isAr ? 'أضف المزيد من الأسماء' : 'Add more names';

  // Step 2
  String people(String names) => isAr ? 'الأشخاص: $names' : 'People: $names';
  String get step2Title => isAr ? 'الخطوة 2 — أضف العناصر.' : 'Step 2 — Add items.';
  String get itemFormat => isAr ? 'الصيغة: اسم العنصر · السعر · من' : 'Format: item name · price · who';
  String get itemExample1 => isAr ? 'برجر 35 أحمد ← لأحمد وحده' : 'Burger 35 Ahmed → Ahmed alone';
  String get itemExample2 => isAr ? 'بيتزا 90 أحمد, سارة ← تقسيم بينهما' : 'Pizza 90 Ahmed, Sara → split between them';
  String get itemExample3 => isAr ? 'قهوة 18 مُقسمة ← للجميع' : 'Coffee 18 shared → all';
  String get scanTip => isAr ? 'اضغط 📷 لمسح الفاتورة.' : 'Tap 📷 to scan receipt.';
  String get sayDoneWhenFinished => isAr ? 'قل "تم" عند الانتهاء.' : 'Say "done" when finished.';
  String get done => isAr ? 'تم ✓' : 'Done ✓';
  String get addMore => isAr ? 'أضف المزيد' : 'Add more';
  String get addItemFirst => isAr ? 'أضف عنصراً واحداً على الأقل أولاً.' : 'Add at least one item first.';
  String get cantParseItem => isAr ? 'لم أفهم ذلك. حاول: برجر 35 أحمد' : 'Couldn\'t parse that. Try: Burger 35 Ahmed';
  String runningTotal(String amount) => isAr ? 'اجمالي الفاتورة: $amount' : 'Running total: $amount';
  String get shared => isAr ? 'مُقسمة' : 'shared';
  String get added => isAr ? 'تمت الإضافة:' : 'Added:';

  // Edit
  String get hereAreItems => isAr ? 'إليك جميع عناصرك:' : 'Here are all your items:';
  String subtotal(String amount) => isAr ? 'المجموع الفرعي: $amount' : 'Subtotal: $amount';
  String get wantToEdit => isAr ? 'هل تريد تعديل شيء؟' : 'Want to edit anything?';
  String get editExample1 => isAr ? 'تعديل برجر 40 ← تغيير السعر' : 'edit Burger 40 ← change price';
  String get editExample2 => isAr ? 'تعديل بيتزا أحمد سارة ← تغيير الأشخاص' : 'edit Pizza Ahmed Sara ← change who';
  String get editExample3 => isAr ? 'حذف بطاطس ← إزالة العنصر' : 'remove Fries ← remove item';
  String get allGood => isAr ? 'كل شيء صحيح ✓' : 'All good ✓';
  String itemNotFound(String item) => isAr ? 'لم أجد "$item"' : 'Couldn\'t find "$item"';
  String itemRemoved(String item) => isAr ? 'تم حذف "$item" ✓' : '"$item" removed ✓';
  String itemUpdated(String item) => isAr ? 'تم تحديث "$item" ✓' : '"$item" updated ✓';
  String get anythingElse => isAr ? 'هل تريد تعديل شيء آخر؟' : 'Anything else to edit?';
  String get editCantUnderstand => isAr
      ? 'لم أفهم ذلك.\n\nحاول:\n  تعديل برجر 40\n  تعديل بيتزا أحمد سارة\n  حذف قهوة'
      : 'I didn\'t understand that.\n\nTry:\n  edit Burger 40\n  edit Pizza Ahmed Sara\n  remove Coffee';

  // Step 3 VAT
  String get step3Title => isAr ? 'الخطوة 3 — ضريبة القيمة المضافة' : 'Step 3 — VAT / Tax';
  String get quickOptionOrCustom => isAr ? 'اختر خياراً سريعاً أو اكتب نسبة مخصصة:' : 'Tap a quick option or type a custom percentage:';
  String get noVat => isAr ? 'لا ضريبة ✓' : 'No VAT ✓';
  String vatApplied(double n) => isAr ? 'ضريبة ${n.toStringAsFixed(0)}% ✓' : 'VAT ${n.toStringAsFixed(0)}% ✓';
  String get custom => isAr ? 'قيمة اخري' : 'Custom';
  String get typeVat => isAr ? 'اكتب نسبة الضريبة (مثال: 7):' : 'Type your VAT percentage (e.g. 7):';
  String vatConfirm(double n) => isAr ? 'ضريبة ${n.toStringAsFixed(1)}% — هل هذا صحيح؟' : 'VAT: ${n.toStringAsFixed(1)}% — correct?';
  String get change => isAr ? 'تغيير' : 'Change';
  String get typeValidNumber => isAr ? 'يرجى إدخال رقم مثل 5، أو اختر خياراً سريعاً.' : 'Please enter a number like 5, or tap a quick option above.';

  // Step 4 Service
  String get step4Title => isAr ? 'الخطوة 4 — رسوم الخدمة' : 'Step 4 — Service charge';
  String get noService => isAr ? 'لا رسوم خدمة ✓' : 'No service charge ✓';
  String serviceApplied(double n) => isAr ? 'خدمة ${n.toStringAsFixed(0)}% ✓' : 'Service ${n.toStringAsFixed(0)}% ✓';
  String get typeService => isAr ? 'اكتب نسبة رسوم الخدمة (مثال: 10):' : 'Type your service charge percentage (e.g. 10):';
  String serviceConfirm(double n) => isAr ? 'رسوم الخدمة ${n.toStringAsFixed(1)}% — هل هذا صحيح؟' : 'Service: ${n.toStringAsFixed(1)}% — correct?';

  // Step 5 Tip
  String get step5Title => isAr ? 'الخطوة 5 — الإكرامية (اختياري)' : 'Step 5 — Tip (optional)';
  String get noTip => isAr ? 'لا إكرامية ✓' : 'No tip ✓';
  String tipApplied(double n) => isAr ? 'إكرامية ${n.toStringAsFixed(0)}% ✓' : 'Tip ${n.toStringAsFixed(0)}% ✓';
  String get typeTip => isAr ? 'اكتب نسبة الإكرامية (مثال: 10):' : 'Type your tip percentage (e.g. 10):';
  String tipConfirm(double n) => isAr ? 'الإكرامية ${n.toStringAsFixed(1)}% — هل هذا صحيح؟' : 'Tip: ${n.toStringAsFixed(1)}% — correct?';

  // Step 6 Final confirm
  String get finalConfirmTitle => isAr ? 'التأكيد النهائي:' : 'Final confirmation:';
  String get peopleLabel => isAr ? 'الأشخاص:' : 'People:';
  String itemsCount(int n) => isAr ? 'العناصر: $n عناصر' : 'Items: $n items';
  String get vatNone => isAr ? 'الضريبة:    لا يوجد' : 'VAT:      None';
  String get serviceNone => isAr ? 'الخدمة:     لا يوجد' : 'Service:  None';
  String get tipNone => isAr ? 'الإكرامية:  لا يوجد' : 'Tip:      None';
  String vatLine(double pct, String amt) => isAr ? 'الضريبة ${pct.toStringAsFixed(0)}%:    $amt' : 'VAT ${pct.toStringAsFixed(0)}%:      $amt';
  String serviceLine(double pct, String amt) => isAr ? 'الخدمة ${pct.toStringAsFixed(0)}%:    $amt' : 'Service ${pct.toStringAsFixed(0)}%:  $amt';
  String tipLine(double pct, String amt) => isAr ? 'الإكرامية ${pct.toStringAsFixed(0)}%: $amt' : 'Tip ${pct.toStringAsFixed(0)}%:      $amt';
  String grandTotalLine(String amt) => isAr ? 'المجموع الكلي: $amt' : 'Grand total: $amt';
  String get allGoodQuestion => isAr ? 'كل شيء صحيح؟' : 'All good?';
  String get calculate => isAr ? 'نعم — احسب!' : 'Yes — calculate! →';
  String get changeVat => isAr ? 'تغيير الضريبة' : 'Change VAT';
  String get changeService => isAr ? 'تغيير الخدمة' : 'Change service';
  String get changeTip => isAr ? 'تغيير الإكرامية' : 'Change tip';
  String get tapCalculate => isAr ? 'اضغط "نعم — احسب!" أعلاه، أو اختر ما تريد تغييره.' : 'Tap "Yes — calculate!" above, or choose what to change.';

  // Step 7 Result
  String finalSplit(String merchant) => isAr ? 'إليك التقسيم النهائي${merchant.isNotEmpty ? " لـ $merchant" : ""}:' : 'Here\'s the final split${merchant.isNotEmpty ? " for $merchant" : ""}:';
  String get grandTotal => isAr ? 'المجموع الكلي' : 'Grand total';
  String get perPerson => isAr ? 'لكل شخص' : 'Per person';
  String get copy => isAr ? 'نسخ' : 'Copy';
  String get share => isAr ? 'مشاركة' : 'Share';
  String get newBill => isAr ? 'فاتورة جديدة' : 'New bill';
  String get billDone => isAr ? 'تم! اضغط "فاتورة جديدة" للبدء من جديد.' : 'Bill is done! Tap "New bill" to start again.';
  String get copied => isAr ? 'تم النسخ!' : 'Copied!';

  // OCR
  String get scanning => isAr ? '📷 جاري مسح الفاتورة…' : '📷 Scanning receipt…';
  String get arabicReceiptDetected => isAr ? 'تم اكتشاف فاتورة عربية. يرجى إضافة العناصر بالكتابة أو الصوت.' : 'Arabic receipt detected. Please add items by typing or voice.';
  String get addItemsManually => isAr ? 'أضف العناصر يدوياً' : 'Add items manually';
  String scannedItems(int n) => isAr ? 'تم المسح ✓ $n عناصر:' : 'Scanned ✓ $n items:';
  String get cantReadReceipt => isAr ? 'لم أتمكن من قراءة أي عناصر. جرب صورة أوضح.' : 'Couldn\'t read any items. Try a clearer photo.';
  String get whoOrderedWhat => isAr ? 'أخبرني من طلب ماذا أو اضغط "تقسيم بالتساوي".' : 'Tell me who ordered what or tap "Split equally".';
  String get splitEqually => isAr ? 'تقسيم بالتساوي' : 'Split equally →';
  String get addMoreItems => isAr ? 'أضف المزيد من العناصر' : 'Add more items';
  String get cantScanReceipt => isAr ? 'لم أتمكن من مسح الفاتورة. جرب صورة أوضح أو أضف العناصر يدوياً.' : 'Couldn\'t scan the receipt. Try a clearer photo or add items manually.';
  String get whatElse => isAr ? 'ماذا تريد إضافة؟' : 'What else?';

  // Share
  String shareHeader(String merchant) => '🧾 $merchant';
  String get billWord => isAr ? 'الفاتورة' : 'Bill';
  String get shareFooter => isAr ? 'تم التقسيم عبر Split Check' : 'Split via Split Check';
  
  // Format number in current language
  String fmtNum(double n, {int decimals = 2}) {
    final str = n.toStringAsFixed(decimals);
    return isAr ? toArabicDigits(str) : str;
  }
  String get vatLabel => isAr ? 'ضريبة' : 'VAT';
  String get serviceLabel => isAr ? 'خدمة' : 'Service';
  String get tipLabel => isAr ? 'إكرامية' : 'Tip';

  // New flow strings
  String get howManyItems => isAr ? 'كم عدد العناصر في الفاتورة؟' : 'How many items are on the bill?';
  String get howManyMoreItems => isAr ? 'كم عدد العناصر الإضافية؟' : 'How many more items?';
  String itemNamePrompt(int current, int total) => isAr ? 'العنصر $current من $total — ما اسم الطبق؟' : 'Item $current of $total — What\'s the item name?';
  String itemPricePrompt(String name) => isAr ? 'ما هو سعر $name؟' : 'What\'s the price of $name?';
  String itemWhoPrompt(String name, String price) => isAr ? 'من طلب $name ($price)؟' : 'Who ordered $name ($price)?';
  String get confirm => isAr ? 'تأكيد ✓' : 'Confirm ✓';
  String get everyone => isAr ? 'الجميع' : 'Everyone';
  String get looksGood => isAr ? 'يبدو جيداً ✓' : 'Looks good ✓';
  String get addMoreItemsBtn => isAr ? 'أضف المزيد من العناصر' : 'Add more items';
  String get editExistingItem => isAr ? 'تعديل عنصر موجود' : 'Edit an existing item';
  String get everythingLooksGood => isAr ? 'كل شيء يبدو جيداً ✓' : 'Everything looks good ✓';
  String get editBtn => isAr ? 'تعديل ✏️' : 'Edit ✏️';
  String get whatToEdit => isAr ? 'ماذا تريد تعديل؟' : 'What would you like to edit?';
  String get editPeople => isAr ? '👥 الأشخاص' : '👥 People';
  String get editNumberOfItems => isAr ? '🔢 عدد العناصر' : '🔢 Number of items';
  String get editItems => isAr ? '🍔 العناصر' : '🍔 Items';
  String get editVat => isAr ? '💰 الضريبة' : '💰 VAT';
  String get editService => isAr ? '🛎 الخدمة' : '🛎 Service';
  String get editTip => isAr ? '💵 الإكرامية' : '💵 Tip';
  String get whichItemToEdit => isAr ? 'أي عنصر تريد تعديله؟' : 'Which item do you want to edit?';
  String get whatToChangeInItem => isAr ? 'ماذا تريد تغيير؟' : 'What do you want to change?';
  String get editName => isAr ? 'الاسم' : 'Name';
  String get editPrice => isAr ? 'السعر' : 'Price';
  String get editWhoOrdered => isAr ? 'من طلبه' : 'Who ordered it';
  String get deleteItem => isAr ? 'حذف العنصر' : 'Delete item';
  String get enterNewName => isAr ? 'أدخل الاسم الجديد:' : 'Enter new name:';
  String get enterNewPrice => isAr ? 'أدخل السعر الجديد:' : 'Enter new price:';
  String get noVatChip => isAr ? 'بدون ضريبة' : 'No VAT';
  String get noServiceChip => isAr ? 'بدون خدمة' : 'No Service';
  String get noTipChip => isAr ? 'بدون إكرامية' : 'No Tip';
  String get discountQuestion => isAr ? 'هل يوجد خصم أو قسيمة؟' : 'Any discounts or vouchers?';
  String get noDiscount => isAr ? 'لا يوجد خصم ✓' : 'No discount ✓';
  String get percentDiscount => isAr ? '% خصم نسبة' : '% Discount';
  String get fixedDiscount => isAr ? '\$\$ مبلغ ثابت' : '\$\$ Fixed amount';
  String get enterDiscountPct => isAr ? 'أدخل نسبة الخصم (مثال: 10 لخصم 10%):' : 'Enter discount percentage (e.g. 10 for 10% off):';
  String get enterDiscountFixed => isAr ? 'أدخل مبلغ الخصم أو القسيمة:' : 'Enter discount or voucher amount:';
  String discountPctApplied(double n) => isAr ? 'خصم \${n.toStringAsFixed(0)}% ✓' : '\${n.toStringAsFixed(0)}% discount applied ✓';
  String discountFixedApplied(double n) => isAr ? 'خصم \$n ✓' : '\$n discount applied ✓';
  String get discountLabel => isAr ? 'الخصم' : 'Discount';
  String itemConfirmed(String name, String price, String who) => isAr ? '✓ $name $price → $who' : '✓ $name $price → $who';
  String allItemsAdded(String subtotal) => isAr ? 'تمت إضافة جميع العناصر:\n\nالمجموع الفرعي: $subtotal' : 'All items added:\n\nSubtotal: $subtotal';
  String get pleaseEnterValidNumber => isAr ? 'يرجى إدخال رقم صحيح' : 'Please enter a valid number';
  String get selectAtLeastOne => isAr ? 'يرجى اختيار شخص واحد على الأقل' : 'Please select at least one person';
}
