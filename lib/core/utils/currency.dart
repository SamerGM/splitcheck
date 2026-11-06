// lib/core/utils/currency.dart

/// Currencies offered in the picker. Code → (English symbol, Arabic symbol, decimals).
const Map<String, (String, String, int)> kCurrencies = {
  'USD': ('\$', '\$', 2),
  'AED': ('AED', 'د.إ', 2),
  'SAR': ('SAR', 'ر.س', 2),
  'QAR': ('QAR', 'ر.ق', 2),
  'KWD': ('KWD', 'د.ك', 3),
  'BHD': ('BHD', 'د.ب', 3),
  'OMR': ('OMR', 'ر.ع', 3),
  'JOD': ('JOD', 'د.أ', 3),
  'EGP': ('EGP', 'ج.م', 2),
  'EUR': ('€', '€', 2),
  'GBP': ('£', '£', 2),
  'LBP': ('LBP', 'ل.ل', 0),
  'MAD': ('MAD', 'د.م', 2),
  'TND': ('TND', 'د.ت', 3),
  'DZD': ('DZD', 'د.ج', 2),
  'IQD': ('IQD', 'د.ع', 0),
  'LYD': ('LYD', 'د.ل', 3),
  'TRY': ('₺', '₺', 2),
  'CAD': ('CAD', 'CAD', 2),
  'AUD': ('AUD', 'AUD', 2),
  'INR': ('₹', '₹', 2),
  'PKR': ('PKR', 'PKR', 0),
};

int currencyDecimals(String currency) => kCurrencies[currency]?.$3 ?? 2;

/// Formats an amount with the bill's currency, e.g. "AED 12.50" / "12.50 د.إ" / "$12.50".
String fmtAmount(double amount, String currency, {bool arabic = false}) {
  final c = kCurrencies[currency] ?? (currency, currency, 2);
  final num = amount.toStringAsFixed(c.$3);
  final sym = arabic ? c.$2 : c.$1;
  if (sym.length == 1) return '$sym$num'; // $, €, £ prefix without space
  return arabic ? '$num $sym' : '$sym $num';
}

/// Display names for the currency picker: code → (English, Arabic).
const Map<String, (String, String)> kCurrencyNames = {
  'AED': ('UAE Dirham', 'درهم إماراتي'),
  'SAR': ('Saudi Riyal', 'ريال سعودي'),
  'QAR': ('Qatari Riyal', 'ريال قطري'),
  'KWD': ('Kuwaiti Dinar', 'دينار كويتي'),
  'BHD': ('Bahraini Dinar', 'دينار بحريني'),
  'OMR': ('Omani Rial', 'ريال عماني'),
  'JOD': ('Jordanian Dinar', 'دينار أردني'),
  'EGP': ('Egyptian Pound', 'جنيه مصري'),
  'USD': ('US Dollar', 'دولار أمريكي'),
  'EUR': ('Euro', 'يورو'),
  'GBP': ('British Pound', 'جنيه إسترليني'),
  'LBP': ('Lebanese Pound', 'ليرة لبنانية'),
  'MAD': ('Moroccan Dirham', 'درهم مغربي'),
  'TND': ('Tunisian Dinar', 'دينار تونسي'),
  'DZD': ('Algerian Dinar', 'دينار جزائري'),
  'IQD': ('Iraqi Dinar', 'دينار عراقي'),
  'LYD': ('Libyan Dinar', 'دينار ليبي'),
  'TRY': ('Turkish Lira', 'ليرة تركية'),
  'CAD': ('Canadian Dollar', 'دولار كندي'),
  'AUD': ('Australian Dollar', 'دولار أسترالي'),
  'INR': ('Indian Rupee', 'روبية هندية'),
  'PKR': ('Pakistani Rupee', 'روبية باكستانية'),
};
