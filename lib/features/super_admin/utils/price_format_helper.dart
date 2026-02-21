/// Formátování částky podle měny tenanta (CZK, EUR, USD).
///
/// Používá se v Tenant Detail pro zobrazení cen modulů a MRR.
String formatPrice(double amount, String currencyCode) {
  final code = currencyCode.toUpperCase();
  switch (code) {
    case 'EUR':
      return '€ ${amount.toStringAsFixed(2)}';
    case 'USD':
      return '\$${amount.toStringAsFixed(2)}';
    case 'CZK':
    default:
      return '${amount.toStringAsFixed(0)} Kč';
  }
}
