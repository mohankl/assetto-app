import 'package:flutter_test/flutter_test.dart';
import 'package:assetto/utils/currency_format.dart';

void main() {
  test('uses rupee symbol', () {
    expect(appCurrencySymbol, '₹');
  });

  test('formats whole rupee amounts with Indian grouping', () {
    expect(formatCurrency(152900), '₹1,52,900');
    expect(formatCurrency(0), '₹0');
  });

  test('formats decimal rupee amounts when requested', () {
    expect(formatCurrency(1234.5, decimalDigits: 2), '₹1,234.50');
  });
}
