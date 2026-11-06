// lib/core/utils/countries.dart
//
// Countries offered in the "country / currency" picker: Arab countries first,
// then the most common others. Each maps to the currency used there and the
// usual VAT / service charge added on restaurant bills (editable every time).

class Country {
  final String code;     // ISO 3166 alpha-2
  final String flag;
  final String en;
  final String ar;
  final String currency; // key in kCurrencies
  /// Usual restaurant VAT % added on the bill (0 where menu prices already include tax).
  final double vat;
  /// Usual service charge %.
  final double service;
  const Country(this.code, this.flag, this.en, this.ar, this.currency, [this.vat = 0, this.service = 0]);

  String name(bool isAr) => isAr ? ar : en;
}

const List<Country> kCountries = [
  Country('EG', '🇪🇬', 'Egypt', 'مصر', 'EGP', 14, 12),
  Country('AE', '🇦🇪', 'United Arab Emirates', 'الإمارات', 'AED', 5, 10),
  Country('SA', '🇸🇦', 'Saudi Arabia', 'السعودية', 'SAR', 15, 0),
  Country('QA', '🇶🇦', 'Qatar', 'قطر', 'QAR', 0, 10),
  Country('KW', '🇰🇼', 'Kuwait', 'الكويت', 'KWD', 0, 0),
  Country('BH', '🇧🇭', 'Bahrain', 'البحرين', 'BHD', 10, 0),
  Country('OM', '🇴🇲', 'Oman', 'عُمان', 'OMR', 5, 0),
  Country('JO', '🇯🇴', 'Jordan', 'الأردن', 'JOD', 16, 10),
  Country('LB', '🇱🇧', 'Lebanon', 'لبنان', 'LBP', 11, 0),
  Country('IQ', '🇮🇶', 'Iraq', 'العراق', 'IQD', 0, 0),
  Country('MA', '🇲🇦', 'Morocco', 'المغرب', 'MAD', 10, 0),
  Country('TN', '🇹🇳', 'Tunisia', 'تونس', 'TND', 7, 0),
  Country('DZ', '🇩🇿', 'Algeria', 'الجزائر', 'DZD', 9, 0),
  Country('LY', '🇱🇾', 'Libya', 'ليبيا', 'LYD', 0, 0),
  Country('US', '🇺🇸', 'United States', 'الولايات المتحدة', 'USD', 0, 0),
  Country('GB', '🇬🇧', 'United Kingdom', 'المملكة المتحدة', 'GBP', 0, 12.5),
  Country('DE', '🇩🇪', 'Germany', 'ألمانيا', 'EUR', 0, 0),
  Country('FR', '🇫🇷', 'France', 'فرنسا', 'EUR', 0, 0),
  Country('IT', '🇮🇹', 'Italy', 'إيطاليا', 'EUR', 0, 0),
  Country('ES', '🇪🇸', 'Spain', 'إسبانيا', 'EUR', 0, 0),
  Country('NL', '🇳🇱', 'Netherlands', 'هولندا', 'EUR', 0, 0),
  Country('TR', '🇹🇷', 'Turkey', 'تركيا', 'TRY', 0, 0),
  Country('CA', '🇨🇦', 'Canada', 'كندا', 'CAD', 0, 0),
  Country('AU', '🇦🇺', 'Australia', 'أستراليا', 'AUD', 0, 0),
  Country('IN', '🇮🇳', 'India', 'الهند', 'INR', 5, 0),
  Country('PK', '🇵🇰', 'Pakistan', 'باكستان', 'PKR', 0, 0),
];

Country? countryByCode(String? code) {
  for (final c in kCountries) { if (c.code == code) return c; }
  return null;
}

/// First country that uses this currency (for showing a flag next to it).
Country? countryForCurrency(String currency) {
  for (final c in kCountries) { if (c.currency == currency) return c; }
  return null;
}
