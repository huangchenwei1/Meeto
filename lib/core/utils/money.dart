/// Money formatting for the demo build.
///
/// Amounts are integers in the smallest display unit (whole pesos). In
/// production, move to a `Money` type with currency codes from the backend.
abstract final class MoneyFormat {
  static const String _currencySymbol = '\u20b1';

  /// Formats `1400` as `₱1,400`.
  static String format(int amount) {
    final String digits = amount.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final int remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    final String sign = amount < 0 ? '-' : '';
    return '$sign$_currencySymbol$buffer';
  }
}
