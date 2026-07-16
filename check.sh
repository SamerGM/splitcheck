#!/bin/bash
echo "================================================"
echo "       SPLITCHECK PRE-PUSH CHECKLIST"
echo "================================================"
ERRORS=()

# 1. Dart errors
{ flutter analyze lib/ 2>&1 | grep -E "^  error" > /dev/null && ERRORS+=("1. Dart errors found"); } || true

# 2. Key Android files exist
{ ls android/app/build.gradle.kts android/settings.gradle.kts android/app/src/main/kotlin/com/samer/splitcheck/MainActivity.kt > /dev/null 2>&1 || ERRORS+=("2. Missing key Android files"); }

# 3. speech_to_text disabled
{ grep -q "speech_to_text" pubspec.yaml || ERRORS+=("3. speech_to_text missing from pubspec"); }

# 4. Gradle newDsl=false
{ grep -q "android.newDsl=false" android/gradle.properties || ERRORS+=("4. newDsl should be false"); }

# 5. AndroidX enabled
{ grep -q "android.useAndroidX=true" android/gradle.properties || ERRORS+=("5. AndroidX not enabled"); }

# 6. builtInKotlin=false
{ grep -q "android.builtInKotlin=false" android/gradle.properties || ERRORS+=("6. builtInKotlin should be false"); }

# 7. Gradle wrapper version
{ grep -q "gradle-9" android/gradle/wrapper/gradle-wrapper.properties || ERRORS+=("7. Gradle wrapper version unexpected"); }

# 8. Package name consistent
{ grep -q "com.samer.splitcheck" android/app/build.gradle.kts || ERRORS+=("8. Package name wrong in build.gradle.kts"); }
{ grep -q "com.samer.splitcheck" android/app/src/main/kotlin/com/samer/splitcheck/MainActivity.kt || ERRORS+=("8. Package name wrong in MainActivity"); }

# 9. compileSdk = 36
{ grep -q "compileSdk = 36" android/app/build.gradle.kts || ERRORS+=("9. compileSdk not 36"); }

# 10. NDK version
{ grep -q "ndkVersion = \"28.2.13676358\"" android/app/build.gradle.kts || ERRORS+=("10. NDK version wrong"); }

# 11. minSdk and targetSdk
{ grep -q "minSdk = 21" android/app/build.gradle.kts || ERRORS+=("11. minSdk not 21"); }
{ grep -q "targetSdk = 35" android/app/build.gradle.kts || ERRORS+=("11. targetSdk not 35"); }

# 12. Signing config
{ grep -q "signingConfigs" android/app/build.gradle.kts || ERRORS+=("12. Signing config missing"); }
{ grep -q "signingConfig = signingConfigs.getByName" android/app/build.gradle.kts || ERRORS+=("12. Release not signed"); }

# 13. key.properties exists
{ ls android/key.properties > /dev/null 2>&1 || ERRORS+=("13. key.properties missing"); }

# 14. Workflow secrets
{ grep -q "KEYSTORE_BASE64" .github/workflows/build.yml || ERRORS+=("14. KEYSTORE_BASE64 missing"); }
{ grep -q "STORE_PASSWORD" .github/workflows/build.yml || ERRORS+=("14. STORE_PASSWORD missing"); }
{ grep -q "KEY_PASSWORD" .github/workflows/build.yml || ERRORS+=("14. KEY_PASSWORD missing"); }
{ grep -q "KEY_ALIAS" .github/workflows/build.yml || ERRORS+=("14. KEY_ALIAS missing"); }

# 15. CRITICAL: github.run_number for unique version code
{ grep -q "github.run_number" .github/workflows/build.yml || ERRORS+=("15. ⚠️ CRITICAL: github.run_number missing - PLAY STORE WILL REJECT AAB"); }

# 16. Workflow steps
{ grep -q "Bump version code" .github/workflows/build.yml || ERRORS+=("16. Version bump step missing"); }
{ grep -q "Build AAB" .github/workflows/build.yml || ERRORS+=("16. Build AAB step missing"); }
{ grep -q "Upload AAB" .github/workflows/build.yml || ERRORS+=("16. Upload AAB step missing"); }
{ grep -q "branches: \[ main \]" .github/workflows/build.yml || ERRORS+=("16. Workflow trigger wrong"); }

# 17. Proguard rules
{ grep -q "com.google.android.play.core" android/app/proguard-rules.pro || ERRORS+=("17. Proguard Play Core rules missing"); }
{ grep -q "com.google.mlkit" android/app/proguard-rules.pro || ERRORS+=("17. Proguard ML Kit rules missing"); }
{ grep -q "io.flutter" android/app/proguard-rules.pro || ERRORS+=("17. Proguard Flutter rules missing"); }

# 18. Launcher icons all 5 sizes
{ ls android/app/src/main/res/mipmap-hdpi/ic_launcher.png > /dev/null 2>&1 || ERRORS+=("18. Launcher icon hdpi missing"); }
{ ls android/app/src/main/res/mipmap-mdpi/ic_launcher.png > /dev/null 2>&1 || ERRORS+=("18. Launcher icon mdpi missing"); }
{ ls android/app/src/main/res/mipmap-xhdpi/ic_launcher.png > /dev/null 2>&1 || ERRORS+=("18. Launcher icon xhdpi missing"); }
{ ls android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png > /dev/null 2>&1 || ERRORS+=("18. Launcher icon xxhdpi missing"); }
{ ls android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png > /dev/null 2>&1 || ERRORS+=("18. Launcher icon xxxhdpi missing"); }

# 19. App icon asset
{ ls assets/icon/icon.png > /dev/null 2>&1 || ERRORS+=("19. App icon asset missing"); }

# 20. pubspec dependencies
{ grep -q "flutter_riverpod" pubspec.yaml || ERRORS+=("20. flutter_riverpod missing"); }
{ grep -q "hive_flutter" pubspec.yaml || ERRORS+=("20. hive_flutter missing"); }
{ grep -q "google_mlkit_text_recognition" pubspec.yaml || ERRORS+=("20. google_mlkit missing"); }
{ grep -q "image_picker" pubspec.yaml || ERRORS+=("20. image_picker missing"); }
{ grep -q "share_plus: \^13" pubspec.yaml || ERRORS+=("20. share_plus wrong version"); }
{ grep -q "path_provider" pubspec.yaml || ERRORS+=("20. path_provider missing"); }
{ grep -q "flutter_launcher_icons" pubspec.yaml || ERRORS+=("20. flutter_launcher_icons missing"); }

# 21. Currency format
{ grep -q "toStringAsFixed(2)" lib/core/utils/currency.dart || ERRORS+=("21. Currency format broken"); }

# 22. Result card
{ grep -q "FittedBox" lib/features/result/result_card.dart || ERRORS+=("22. FittedBox missing in result card"); }
{ grep -q "RepaintBoundary" lib/features/result/result_card.dart || ERRORS+=("22. RepaintBoundary missing for image share"); }
{ grep -q "share_plus" lib/features/result/result_card.dart || ERRORS+=("22. share_plus not imported in result_card"); }

# 23. Chat screen
{ grep -q "onRestart" lib/features/flow/chat_screen.dart || ERRORS+=("23. onRestart missing"); }
{ grep -q "ImageSource.camera" lib/features/flow/chat_screen.dart || ERRORS+=("23. Camera option missing"); }
{ grep -q "ImageSource.gallery" lib/features/flow/chat_screen.dart || ERRORS+=("23. Gallery option missing"); }
{ grep -q "_NameSelector" lib/features/flow/chat_screen.dart || ERRORS+=("23. NameSelector widget missing"); }
{ grep -q "_NameSelectorState" lib/features/flow/chat_screen.dart || ERRORS+=("23. NameSelectorState missing"); }

# 24. Flow controller
{ grep -q "confirmSelectedPeople" lib/features/flow/flow_controller.dart || ERRORS+=("24. confirmSelectedPeople missing"); }
{ grep -q "Future<void> reset()" lib/features/flow/flow_controller.dart || ERRORS+=("24. reset() missing"); }
{ grep -q "howManyItems\|itemCount" lib/features/flow/flow_controller.dart || ERRORS+=("24. New item flow missing"); }
{ grep -q "low == 'yes'" lib/features/flow/flow_controller.dart || ERRORS+=("24. Typed yes/no for people missing"); }

# 25. Providers
{ grep -q "itemCount" lib/core/services/providers.dart || ERRORS+=("25. itemCount FlowStep missing"); }
{ grep -q "itemName" lib/core/services/providers.dart || ERRORS+=("25. itemName FlowStep missing"); }
{ grep -q "itemWho" lib/core/services/providers.dart || ERRORS+=("25. itemWho FlowStep missing"); }

# 26. Strings bilingual
{ grep -q "isAr" lib/core/utils/strings.dart || ERRORS+=("26. Arabic strings missing"); }
{ grep -q "howManyItems" lib/core/utils/strings.dart || ERRORS+=("26. New flow strings missing"); }
{ grep -q "confirmSelectedPeople\|looksGood" lib/core/utils/strings.dart || ERRORS+=("26. looksGood string missing"); }

# 27. Settings provider
{ grep -q "stringsProvider" lib/core/services/settings_provider.dart || ERRORS+=("27. stringsProvider missing"); }
{ grep -q "languageProvider" lib/core/services/settings_provider.dart || ERRORS+=("27. languageProvider missing"); }

# 28. MainActivity correct
{ grep -q "FlutterActivity" android/app/src/main/kotlin/com/samer/splitcheck/MainActivity.kt || ERRORS+=("28. MainActivity wrong"); }

# 29. Version format
{ grep -q "^version: .*+[0-9]" pubspec.yaml || ERRORS+=("29. Version format wrong"); }

# 30. settings.gradle.kts has correct plugins
{ grep -q "dev.flutter.flutter-plugin-loader" android/settings.gradle.kts || ERRORS+=("30. Flutter plugin loader missing"); }
{ grep -q "com.android.application" android/settings.gradle.kts || ERRORS+=("30. Android application plugin missing"); }

# Summary
echo ""
echo "================================================"
if [ ${#ERRORS[@]} -eq 0 ]; then
  echo "✅ ALL CHECKS PASSED! Safe to push."
else
  echo "❌ ${#ERRORS[@]} ISSUE(S) FOUND - DO NOT PUSH:"
  echo ""
  for e in "${ERRORS[@]}"; do echo "  ⚠️  $e"; done
fi
echo "================================================"

# 71. Progress dots removed from header
{ ! grep -q "FlowStep.values.map" lib/features/flow/chat_screen.dart || ERRORS+=("71. Progress dots still in header"); }

# 72. Header has language on left, SplitCheck center, theme on right
{ grep -q "Language toggle - LEFT" lib/features/flow/chat_screen.dart || ERRORS+=("72. Header layout not updated"); }

# 73. Name selector uses GridView
{ grep -q "GridView.count" lib/features/flow/chat_screen.dart || ERRORS+=("73. Name selector not using grid layout"); }

# 74. Item name prompt updated
{ grep -q "item name" lib/core/utils/strings.dart || ERRORS+=("74. Item name prompt not updated"); }

# 75. Price prompt updated
{ grep -q "price of" lib/core/utils/strings.dart || ERRORS+=("75. Price prompt not updated"); }

# 76. Who ordered prompt updated
{ grep -q "Who ordered" lib/core/utils/strings.dart || ERRORS+=("76. Who ordered prompt not updated"); }

# 77. Floating restart button exists
{ grep -q "FloatingActionButton" lib/features/flow/chat_screen.dart || ERRORS+=("77. Floating restart button missing"); }

# 78. Compact share card in result_card
{ grep -q "Compact share card\|COMPACT SHARE" lib/features/result/result_card.dart || ERRORS+=("78. Compact share card missing"); }

# 79. Full breakdown section in result_card
{ grep -q "Full breakdown\|FULL BREAKDOWN" lib/features/result/result_card.dart || ERRORS+=("79. Full breakdown section missing"); }

# 80. Add more items doesn't clear existing
{ ! grep -q "_draft.clearItems" lib/features/flow/flow_controller.dart || ERRORS+=("80. clearItems still called - will clear items on add more"); }


# 81. No toggles in share image (result_card)
{ ! grep -q "Language toggle\|Theme toggle" lib/features/result/result_card.dart || ERRORS+=("81. Toggles still in share image"); }

# 82. VAT/Service/Tip use Arabic strings
{ grep -q "vatLabel\|serviceLabel\|tipLabel" lib/features/result/result_card.dart || ERRORS+=("82. VAT/Service/Tip not using bilingual labels"); }

# 83. Copy text has separators
{ grep -q '"\*\*\*' lib/features/result/result_card.dart || ERRORS+=("83. Copy text missing separators"); }

# 84. Arabic number normalization exists
{ grep -q "arabicDigits\|normalizeDigits" lib/core/utils/number_parser.dart || ERRORS+=("84. Arabic number normalization missing"); }

# 85. number_parser.dart exists
{ ls lib/core/utils/number_parser.dart > /dev/null 2>&1 || ERRORS+=("85. number_parser.dart missing"); }

# 86. Voice confirmation dialog exists
{ grep -q "_showVoiceConfirmation\|showVoiceConfirmation" lib/features/flow/chat_screen.dart || ERRORS+=("86. Voice confirmation dialog missing"); }

# 87. Draggable restart button exists
{ grep -q "_DraggableRestartButton" lib/features/flow/chat_screen.dart || ERRORS+=("87. Draggable restart button missing"); }

# 88. Restart button removed from input bar column
{ ! grep -q "onRestart.*icon.*refresh" lib/features/flow/chat_screen.dart || ERRORS+=("88. Restart button still in input bar"); }

# 89. image package for OCR preprocessing
{ grep -q "image: " pubspec.yaml || ERRORS+=("89. image package missing for OCR"); }

# 90. OCR preprocessing exists
{ grep -q "_preprocessImage" lib/core/services/ocr_service.dart || ERRORS+=("90. OCR preprocessing missing"); }


# 91. Voice retry logic exists
{ grep -q "_voiceRetried" lib/features/flow/chat_screen.dart || ERRORS+=("91. Voice retry logic missing"); }

# 92. Voice confirmation dialog exists
{ grep -q "_showVoiceConfirmation" lib/features/flow/chat_screen.dart || ERRORS+=("92. Voice confirmation dialog missing"); }

# 93. Arabic digits normalization in number_parser
{ grep -q "arabicDigits\|٠١٢٣" lib/core/utils/number_parser.dart || ERRORS+=("93. Arabic digit normalization missing"); }

# 94. toArabicDigits helper in strings.dart
{ grep -q "toArabicDigits" lib/core/utils/strings.dart || ERRORS+=("94. toArabicDigits helper missing"); }

# 95. مُقسمة replaces مشترك in Arabic
{ grep -q "مُقسمة" lib/core/utils/strings.dart || ERRORS+=("95. Arabic shared word not updated to مُقسمة"); }

# 96. vatLabel serviceLabel tipLabel in strings
{ grep -q "vatLabel\|serviceLabel\|tipLabel" lib/core/utils/strings.dart || ERRORS+=("96. Bilingual VAT/Service/Tip labels missing"); }

# 97. number_parser imported in parser_service
{ grep -q "number_parser" lib/core/services/parser_service.dart || ERRORS+=("97. number_parser not imported in parser_service"); }

# 98. SystemSound import in chat_screen
{ grep -q "flutter/services.dart" lib/features/flow/chat_screen.dart || ERRORS+=("98. Services import missing in chat_screen"); }

# 99. OCR image package exists
{ grep -q "^  image:" pubspec.yaml || ERRORS+=("99. image package missing in pubspec"); }

# 100. Draggable button added to Stack in build
{ grep -q "_DraggableRestartButton" lib/features/flow/chat_screen.dart || ERRORS+=("100. DraggableRestartButton not in build"); }


# 101. flutter-action version is not deprecated
{ grep -q "flutter-action@v2\.[2-9]\|flutter-action@v[3-9]" .github/workflows/build.yml || ERRORS+=("101. flutter-action version may use deprecated cache - update to v2.4.0+"); }

# 102. No deprecated actions/cache v2 in workflow
{ ! grep -q "actions/cache@v2\|actions/cache@v1" .github/workflows/build.yml || ERRORS+=("102. Deprecated actions/cache v1/v2 found in workflow"); }

# 103. Voice retry flag exists
{ grep -q "_voiceRetried" lib/features/flow/chat_screen.dart || ERRORS+=("103. Voice retry flag missing"); }

# 104. مُقسمة used instead of مشترك
{ ! grep -q "'مشترك'" lib/core/services/parser_service.dart || ERRORS+=("104. Old Arabic shared word still in parser"); }

# 105. number_parser.dart has English word parsing
{ grep -q "_enOnes\|_enTens" lib/core/utils/number_parser.dart || ERRORS+=("105. English word-to-number parsing missing"); }


# 106. flutter-action uses latest v2 not pinned to old version
{ grep -q "flutter-action@v2\.1[0-9]\|flutter-action@v[3-9]" .github/workflows/build.yml || ERRORS+=("106. flutter-action pinned to old version - use @v2 for latest"); }


# 107. flutter-action is v2.19.0 or higher (uses cache@v5)
{ grep -q "flutter-action@v2\.19\|flutter-action@v2\.[2-9][0-9]\|flutter-action@v[3-9]" .github/workflows/build.yml || ERRORS+=("107. flutter-action below v2.19.0 - may use deprecated cache@v2"); }


# 108. actions/checkout is v5+ (Node.js 24 native)
{ grep -q "actions/checkout@v[5-9]\|actions/checkout@v[1-9][0-9]" .github/workflows/build.yml || ERRORS+=("108. actions/checkout below v5 - not Node.js 24 native"); }

# 109. actions/setup-java is v5+ (Node.js 24 native)
{ grep -q "actions/setup-java@v[5-9]\|actions/setup-java@v[1-9][0-9]" .github/workflows/build.yml || ERRORS+=("109. actions/setup-java below v5 - not Node.js 24 native"); }

# 110. actions/upload-artifact is v6+ (Node.js 24 native)
{ grep -q "actions/upload-artifact@v[6-9]\|actions/upload-artifact@v[1-9][0-9]" .github/workflows/build.yml || ERRORS+=("110. actions/upload-artifact below v6 - not Node.js 24 native"); }


# 111. normalizeDigits function exists in number_parser
{ grep -q "String normalizeDigits" lib/core/utils/number_parser.dart || ERRORS+=("111. normalizeDigits function missing in number_parser.dart"); }

# 112. parseNumber uses parseNumberFromText
{ grep -q "parseNumberFromText" lib/core/services/parser_service.dart || ERRORS+=("112. parseNumber not using parseNumberFromText - text numbers won't work"); }

# 113. billWord getter exists in strings
{ grep -q "billWord" lib/core/utils/strings.dart || ERRORS+=("113. billWord getter missing in strings.dart"); }

# 114. Bill default removed from bill_draft
{ ! grep -q "': 'Bill'" lib/core/models/bill_draft.dart || ERRORS+=("114. Hardcoded 'Bill' still in bill_draft.dart"); }


# 115. Item count uses parseNumber not int.tryParse
{ ! grep -q "int.tryParse" lib/features/flow/flow_controller.dart || ERRORS+=("115. Item count still using int.tryParse - text numbers won't work"); }

# 116. Item price uses parseNumber not double.tryParse in handler
{ grep -q "final price = parseNumber" lib/features/flow/flow_controller.dart || ERRORS+=("116. Item price not using parseNumber - text numbers won't work"); }

# 117. Voice retry cancels mic on second failure
{ grep -q "voice.cancel" lib/features/flow/chat_screen.dart || ERRORS+=("117. Voice not cancelled on second failure"); }

# 118. Voice error shown in red snackbar
{ grep -q "backgroundColor: Colors.red" lib/features/flow/chat_screen.dart || ERRORS+=("118. Voice error snackbar not styled red"); }

# 119. _fmt helper exists in flow_controller for Arabic numbers
{ grep -q "String _fmt" lib/features/flow/flow_controller.dart || ERRORS+=("119. _fmt helper missing in flow_controller"); }

# 120. toArabicDigits used in flow_controller
{ grep -q "toArabicDigits" lib/features/flow/flow_controller.dart || ERRORS+=("120. toArabicDigits not used in flow_controller"); }


# 121. _fmt used instead of fmtAmount in flow_controller (except inside _fmt itself)
{ grep -q "_fmt(" lib/features/flow/flow_controller.dart || ERRORS+=("121. _fmt not used in flow_controller - Arabic numbers won't display"); }

# 122. normalizeDigits function in number_parser
{ grep -q "String normalizeDigits" lib/core/utils/number_parser.dart || ERRORS+=("122. normalizeDigits missing - Arabic digit input won't work"); }

# 123. parseNumberFromText handles English words
{ grep -q "_enOnes\|thirty\|twenty" lib/core/utils/number_parser.dart || ERRORS+=("123. English word-to-number missing"); }

# 124. parseNumberFromText handles Arabic words
{ grep -q "_arOnes\|ثلاثة\|خمسة" lib/core/utils/number_parser.dart || ERRORS+=("124. Arabic word-to-number missing"); }

# 125. parseNumber calls normalizeDigits
{ grep -q "normalizeDigits" lib/core/services/parser_service.dart || ERRORS+=("125. parseNumber not normalizing Arabic digits"); }


# 126. OCR shows correction flow (Looks good/Edit/Scan again)
{ grep -q "Looks good\|Edit items\|Scan again" lib/features/flow/flow_controller.dart || ERRORS+=("126. OCR correction flow missing"); }

# 127. Voice Arabic locale fallback exists
{ grep -q "ar-EG\|ar-AE\|ar-SA" lib/core/services/voice_service.dart || ERRORS+=("127. Arabic voice locale fallback missing"); }

# 128. Voice listen duration increased
{ grep -q "seconds: 45\|seconds: 60" lib/core/services/voice_service.dart || ERRORS+=("128. Voice listen duration not increased"); }

# 129. Voice pause detection increased
{ grep -q "pauseFor.*seconds: [4-9]\|pauseFor.*seconds: [1-9][0-9]" lib/core/services/voice_service.dart || ERRORS+=("129. Voice pause detection not increased"); }


# 130. _handleVat checks _editingFromMenu for typed input
{ grep -A5 "_handleVat" lib/features/flow/flow_controller.dart | grep -q "_editingFromMenu" || ERRORS+=("130. _handleVat not checking _editingFromMenu - VAT loop bug"); }

# 131. _handleService checks _editingFromMenu for typed input
{ grep -A5 "_handleService" lib/features/flow/flow_controller.dart | grep -q "_editingFromMenu" || ERRORS+=("131. _handleService not checking _editingFromMenu - Service loop bug"); }

# 132. _handleTip checks _editingFromMenu for typed input
{ grep -A5 "_handleTip" lib/features/flow/flow_controller.dart | grep -q "_editingFromMenu" || ERRORS+=("132. _handleTip not checking _editingFromMenu - Tip loop bug"); }

# 133. normalizeDigits imported in flow_controller
{ grep -q "number_parser" lib/features/flow/flow_controller.dart || ERRORS+=("133. number_parser not imported in flow_controller"); }

# 134. Arabic price normalized before parsing
{ grep -q "normalizeDigits.*pendingItemPrice\|normalizeDigits.*priceStr" lib/features/flow/flow_controller.dart || ERRORS+=("134. Arabic price not normalized before parsing"); }

