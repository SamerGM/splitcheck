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
{ grep -q "# speech_to_text" pubspec.yaml || ERRORS+=("3. speech_to_text not disabled"); }

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
{ grep -q "github.run_number" .github/workflows/build.yml || ERRORS+=("15. CRITICAL: github.run_number missing - PLAY STORE WILL REJECT AAB"); }

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
{ grep -q "GlobalKey\|_shareKey" lib/features/result/result_card.dart || ERRORS+=("22. GlobalKey for share missing"); }

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
{ grep -q "clearItems" lib/core/services/providers.dart || ERRORS+=("25. clearItems method missing"); }

# 26. Strings bilingual
{ grep -q "isAr" lib/core/utils/strings.dart || ERRORS+=("26. Arabic strings missing"); }
{ grep -q "howManyItems" lib/core/utils/strings.dart || ERRORS+=("26. New flow strings missing"); }
{ grep -q "looksGood" lib/core/utils/strings.dart || ERRORS+=("26. looksGood string missing"); }

# 27. Settings provider
{ grep -q "stringsProvider" lib/core/services/settings_provider.dart || ERRORS+=("27. stringsProvider missing"); }
{ grep -q "languageProvider" lib/core/services/settings_provider.dart || ERRORS+=("27. languageProvider missing"); }

# 28. MainActivity correct
{ grep -q "FlutterActivity" android/app/src/main/kotlin/com/samer/splitcheck/MainActivity.kt || ERRORS+=("28. MainActivity wrong"); }

# 29. Version format
{ grep -q "^version: .*+[0-9]" pubspec.yaml || ERRORS+=("29. Version format wrong"); }

# 30. settings.gradle.kts plugins
{ grep -q "dev.flutter.flutter-plugin-loader" android/settings.gradle.kts || ERRORS+=("30. Flutter plugin loader missing"); }
{ grep -q "com.android.application" android/settings.gradle.kts || ERRORS+=("30. Android application plugin missing"); }

# 31. Core services exist
{ ls lib/core/services/ocr_service.dart > /dev/null 2>&1 || ERRORS+=("31. OCR service missing"); }
{ ls lib/core/services/edit_parser.dart > /dev/null 2>&1 || ERRORS+=("31. Edit parser missing"); }
{ ls lib/core/services/parser_service.dart > /dev/null 2>&1 || ERRORS+=("31. Parser service missing"); }
{ ls lib/core/services/split_calculator.dart > /dev/null 2>&1 || ERRORS+=("31. Split calculator missing"); }

# 32. BillExtras methods
{ grep -q "vatAmount\|serviceAmount\|tipAmount" lib/core/models/bill_extras.dart || ERRORS+=("32. BillExtras calculation methods missing"); }

# 33. App theme
{ ls lib/shared/theme/app_theme.dart > /dev/null 2>&1 || ERRORS+=("33. App theme missing"); }

# 34. main.dart setup
{ grep -q "ProviderScope" lib/main.dart || ERRORS+=("34. ProviderScope missing in main.dart"); }
{ grep -q "Hive.initFlutter" lib/main.dart || ERRORS+=("34. Hive not initialized in main.dart"); }

# 35. AndroidManifest permissions
{ grep -q "CAMERA" android/app/src/main/AndroidManifest.xml || ERRORS+=("35. Camera permission missing"); }
{ grep -q "RECORD_AUDIO" android/app/src/main/AndroidManifest.xml || ERRORS+=("35. Microphone permission missing"); }
{ grep -q "READ_MEDIA_IMAGES" android/app/src/main/AndroidManifest.xml || ERRORS+=("35. Read media images permission missing"); }

# 36. flutter_animate in pubspec
{ grep -q "flutter_animate" pubspec.yaml || ERRORS+=("36. flutter_animate missing"); }

# 37. Gap package in pubspec
{ grep -q "gap:" pubspec.yaml || ERRORS+=("37. gap package missing"); }

# 38. UUID package in pubspec
{ grep -q "uuid:" pubspec.yaml || ERRORS+=("38. uuid package missing"); }

# 39. intl package in pubspec
{ grep -q "intl:" pubspec.yaml || ERRORS+=("39. intl package missing"); }

# 40. flutter_localizations in pubspec
{ grep -q "flutter_localizations" pubspec.yaml || ERRORS+=("40. flutter_localizations missing"); }

# 41. Result card is ConsumerWidget
{ grep -q "ConsumerWidget" lib/features/result/result_card.dart || ERRORS+=("41. ResultCard not ConsumerWidget"); }

# 42. Chat screen is ConsumerStatefulWidget
{ grep -q "ConsumerStatefulWidget" lib/features/flow/chat_screen.dart || ERRORS+=("42. ChatScreen not ConsumerStatefulWidget"); }

# 43. Flow controller extends Notifier
{ grep -q "extends Notifier" lib/features/flow/flow_controller.dart || ERRORS+=("43. FlowController not extending Notifier"); }

# 44. Bill model exists
{ ls lib/core/models/bill.dart > /dev/null 2>&1 || ERRORS+=("44. Bill model missing"); }

# 45. Person model exists
{ ls lib/core/models/person.dart > /dev/null 2>&1 || ERRORS+=("45. Person model missing"); }

# 46. BillItem model exists
{ ls lib/core/models/bill_item.dart > /dev/null 2>&1 || ERRORS+=("46. BillItem model missing"); }

# 47. kPersonColors defined
{ grep -q "kPersonColors" lib/core/models/models.dart || ERRORS+=("47. kPersonColors missing"); }

# 48. Voice service exists
{ ls lib/core/services/voice_service.dart > /dev/null 2>&1 || ERRORS+=("48. Voice service missing"); }

# 49. Settings service exists
{ ls lib/core/services/settings_service.dart > /dev/null 2>&1 || ERRORS+=("49. Settings service missing"); }

# 50. check.sh is executable
{ test -x check.sh || ERRORS+=("50. check.sh not executable - run chmod +x check.sh"); }

# 51. stringsProvider used in flow_controller
{ grep -q "stringsProvider\|ref.read(stringsProvider)" lib/features/flow/flow_controller.dart || ERRORS+=("51. stringsProvider not used in flow_controller"); }

# 52. Language toggle resets chat
{ grep -q "chatProvider.notifier).reset" lib/features/flow/chat_screen.dart || ERRORS+=("52. Language toggle does not reset chat"); }

# 53. Theme provider in chat screen
{ grep -q "themeProvider" lib/features/flow/chat_screen.dart || ERRORS+=("53. Theme provider not in chat screen"); }

# 54. Arabic keywords in parser
{ grep -q "الكل\|الجميع\|كل" lib/core/services/parser_service.dart || ERRORS+=("54. Arabic shared keywords missing in parser"); }

# 55. Confirm button in NameSelector
{ grep -q "Confirm" lib/features/flow/chat_screen.dart || ERRORS+=("55. Confirm button missing in NameSelector"); }

# 56. Result card shows per person breakdown
{ grep -q "personResults" lib/features/result/result_card.dart || ERRORS+=("56. Per person breakdown missing in result card"); }

# 57. SplitCalculator calculates shares
{ grep -q "vatShare\|serviceShare\|tipShare" lib/core/services/split_calculator.dart || ERRORS+=("57. SplitCalculator not calculating shares"); }

# 58. key.properties in .gitignore
{ grep -q "key.properties" .gitignore || ERRORS+=("58. key.properties not in .gitignore - SECURITY RISK"); }

# 59. assets declared in pubspec
{ grep -q "assets:" pubspec.yaml || ERRORS+=("59. Assets not declared in pubspec"); }
{ grep -q "assets/icon" pubspec.yaml || ERRORS+=("59. assets/icon not declared in pubspec"); }

# 60. No print statements
{ grep -rn "print(" lib/ --include="*.dart" | grep -v "//.*print" > /dev/null && ERRORS+=("60. print() statements found - remove before production"); } || true

# 61. BillDraft has toBill method
{ grep -q "toBill" lib/core/models/bill_draft.dart || ERRORS+=("61. toBill method missing in BillDraft"); }

# 62. grandTotal in SplitResult
{ grep -q "grandTotal" lib/core/models/bill_draft.dart || ERRORS+=("62. grandTotal missing in SplitResult"); }

# 63. App name in AndroidManifest
{ grep -q "SplitCheck" android/app/src/main/AndroidManifest.xml || ERRORS+=("63. App name not SplitCheck in AndroidManifest"); }

# 64. Minification enabled
{ grep -q "isMinifyEnabled = true" android/app/build.gradle.kts || ERRORS+=("64. Minification not enabled for release"); }

# 65. No TODO/FIXME in flow_controller
{ grep -rn "TODO\|FIXME" lib/features/flow/flow_controller.dart > /dev/null && ERRORS+=("65. TODO/FIXME found in flow_controller"); } || true

# 66. pubspec.lock exists
{ ls pubspec.lock > /dev/null 2>&1 || ERRORS+=("66. pubspec.lock missing - run flutter pub get"); }

# 67. Single version in pubspec
{ [ $(grep -c "^version:" pubspec.yaml) -eq 1 ] || ERRORS+=("67. Duplicate version in pubspec"); }

# 68. Workflow name correct
{ grep -q "name: Build Android AAB" .github/workflows/build.yml || ERRORS+=("68. Workflow name wrong or file corrupt"); }

# 69. local.properties in .gitignore
{ grep -q "local.properties" .gitignore || ERRORS+=("69. local.properties not in .gitignore"); }

# 70. kotlin-android plugin in build.gradle.kts
{ grep -q "kotlin-android" android/app/build.gradle.kts || ERRORS+=("70. kotlin-android plugin missing"); }

# Summary
echo ""
echo "================================================"
if [ ${#ERRORS[@]} -eq 0 ]; then
  echo "✅ ALL 70 CHECKS PASSED! Safe to push."
else
  echo "❌ ${#ERRORS[@]} ISSUE(S) FOUND - DO NOT PUSH:"
  echo ""
  for e in "${ERRORS[@]}"; do echo "  ⚠️  $e"; done
fi
echo "================================================"
