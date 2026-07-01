import 'package:intl/intl.dart';

const String appCurrencySymbol = '₹';

NumberFormat appCurrencyFormat({int decimalDigits = 0}) {
  return NumberFormat.currency(
    symbol: appCurrencySymbol,
    locale: 'en_IN',
    decimalDigits: decimalDigits,
  );
}

String formatCurrency(double amount, {int decimalDigits = 0}) {
  return appCurrencyFormat(decimalDigits: decimalDigits).format(amount);
}
