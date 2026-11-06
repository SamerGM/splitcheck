// lib/features/settings/country_picker.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/settings_provider.dart';
import '../../core/utils/countries.dart';
import '../../core/utils/currency.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/apple_widgets.dart';

/// Searchable "country · currency" list. Returns the chosen country, or null.
Future<Country?> showCountryPicker(BuildContext context, {String? selectedCode}) {
  return showAppleSheet<Country>(
    context: context,
    builder: (_) => _CountryList(selectedCode: selectedCode),
  );
}

class _CountryList extends ConsumerStatefulWidget {
  final String? selectedCode;
  const _CountryList({this.selectedCode});
  @override ConsumerState<_CountryList> createState() => _CountryListState();
}

class _CountryListState extends ConsumerState<_CountryList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = ref.watch(stringsProvider);
    final q = _q.trim().toLowerCase();
    final list = kCountries.where((c) =>
        q.isEmpty ||
        c.en.toLowerCase().contains(q) ||
        c.ar.contains(q) ||
        c.currency.toLowerCase().contains(q) ||
        (kCurrencyNames[c.currency]?.$1.toLowerCase().contains(q) ?? false) ||
        (kCurrencyNames[c.currency]?.$2.contains(q) ?? false)).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Text(s.countryCurrency, style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: p.label)),
        const SizedBox(height: 12),
        CupertinoSearchTextField(
          placeholder: s.search,
          onChanged: (v) => setState(() => _q = v),
          style: TextStyle(color: p.label),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: InsetGroup(
            scrollable: true,
            inSheet: true,
            separatorInset: 58,
            children: [
              for (final c in list)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, c);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(children: [
                      SizedBox(width: 32, child: Text(c.flag, style: const TextStyle(fontSize: 24))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name(s.isAr), style: TextStyle(fontSize: 17, letterSpacing: -0.4, color: p.label)),
                        Text(
                          '${s.isAr ? kCurrencyNames[c.currency]!.$2 : kCurrencyNames[c.currency]!.$1} · ${c.currency}',
                          style: TextStyle(fontSize: 13, color: p.secondary)),
                      ])),
                      if (c.code == widget.selectedCode)
                        Icon(CupertinoIcons.checkmark_alt, color: p.accent, size: 22),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}
