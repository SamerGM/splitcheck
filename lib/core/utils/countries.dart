// lib/core/utils/countries.dart
//
// Countries offered in the "country / currency" picker: Arab countries first,
// then the most common others. Each maps to the currency used there.

class Country {
  final String code;     // ISO 3166 alpha-2
  final String flag;
  final String en;
  final String ar;
  final String currency; // key in kCurrencies
  const Country(this.code, this.flag, this.en, this.ar, this.currency);

  String name(bool isAr) => isAr ? ar : en;
}

const List<Country> kCountries = [
  Country('EG', '🇪🇬', 'Egypt', 'مصر', 'EGP'),
  Country('AE', '🇦🇪', 'United Arab Emirates', 'الإمارات', 'AED'),
  Country('SA', '🇸🇦', 'Saudi Arabia', 'السعودية', 'SAR'),
  Country('QA', '🇶🇦', 'Qatar', 'قطر', 'QAR'),
  Country('KW', '🇰🇼', 'Kuwait', 'الكويت', 'KWD'),
  Country('BH', '🇧🇭', 'Bahrain', 'البحرين', 'BHD'),
  Country('OM', '🇴🇲', 'Oman', 'عُمان', 'OMR'),
  Country('JO', '🇯🇴', 'Jordan', 'الأردن', 'JOD'),
  Country('LB', '🇱🇧', 'Lebanon', 'لبنان', 'LBP'),
  Country('IQ', '🇮🇶', 'Iraq', 'العراق', 'IQD'),
  Country('MA', '🇲🇦', 'Morocco', 'المغرب', 'MAD'),
  Country('TN', '🇹🇳', 'Tunisia', 'تونس', 'TND'),
  Country('DZ', '🇩🇿', 'Algeria', 'الجزائر', 'DZD'),
  Country('LY', '🇱🇾', 'Libya', 'ليبيا', 'LYD'),
  Country('US', '🇺🇸', 'United States', 'الولايات المتحدة', 'USD'),
  Country('GB', '🇬🇧', 'United Kingdom', 'المملكة المتحدة', 'GBP'),
  Country('DE', '🇩🇪', 'Germany', 'ألمانيا', 'EUR'),
  Country('FR', '🇫🇷', 'France', 'فرنسا', 'EUR'),
  Country('IT', '🇮🇹', 'Italy', 'إيطاليا', 'EUR'),
  Country('ES', '🇪🇸', 'Spain', 'إسبانيا', 'EUR'),
  Country('NL', '🇳🇱', 'Netherlands', 'هولندا', 'EUR'),
  Country('TR', '🇹🇷', 'Turkey', 'تركيا', 'TRY'),
  Country('CA', '🇨🇦', 'Canada', 'كندا', 'CAD'),
  Country('AU', '🇦🇺', 'Australia', 'أستراليا', 'AUD'),
  Country('IN', '🇮🇳', 'India', 'الهند', 'INR'),
  Country('PK', '🇵🇰', 'Pakistan', 'باكستان', 'PKR'),
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
