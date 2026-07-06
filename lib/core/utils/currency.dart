// lib/core/utils/currency.dart

const Map<String, String> kCurrencySymbols = {
  'AED': 'AED', 'USD': '\$', 'EUR': '€', 'GBP': '£',
  'SAR': 'SAR', 'EGP': 'EGP', 'INR': '₹', 'CAD': 'CA\$', 'AUD': 'A\$',
};

const List<String> kCurrencies = [
  'AED', 'USD', 'EUR', 'GBP', 'SAR', 'EGP', 'INR', 'CAD', 'AUD',
];

String symFor(String currency) => kCurrencySymbols[currency] ?? currency;

String fmtAmount(double amount, String currency) =>
    '${symFor(currency)} ${amount.toStringAsFixed(2)}';
