import 'package:flutter_test/flutter_test.dart';
import 'package:assetto/models/transaction.dart';
import 'package:assetto/utils/billing_month.dart';
import 'package:assetto/utils/currency_format.dart';

Transaction _rent({
  required int year,
  required int month,
  required int day,
  String status = 'pending',
  String description = '',
}) {
  final date = DateTime(year, month, day).millisecondsSinceEpoch;
  return Transaction(
    id: '$year-$month-$day-$status',
    assetId: 'asset-1',
    tenantId: 'tenant-1',
    amount: 9200,
    type: 'rent',
    status: status,
    description: description,
    date: date,
    createdAt: date,
    updatedAt: date,
  );
}

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

  test('uses current month when it has rent invoices', () {
    final transactions = [_rent(year: 2026, month: 7, day: 31)];

    final month = resolveActiveBillingMonth(
      transactions,
      referenceDate: DateTime(2026, 7, 15),
    );

    expect(month, DateTime(2026, 7, 1));
  });

  test('uses billing month from invoice description when date differs', () {
    final transaction = Transaction(
      id: 'june-invoice',
      assetId: 'asset-1',
      tenantId: 'tenant-1',
      amount: 9200,
      type: 'rent',
      status: 'pending',
      description: 'June 2026 invoice system entry',
      date: DateTime(2026, 4, 30).millisecondsSinceEpoch,
      createdAt: DateTime(2026, 4, 30).millisecondsSinceEpoch,
      updatedAt: DateTime(2026, 4, 30).millisecondsSinceEpoch,
    );

    expect(
      resolveTransactionBillingMonth(transaction),
      DateTime(2026, 6, 1),
    );
    expect(isRentInBillingMonth(transaction, DateTime(2026, 6, 1)), isTrue);
    expect(isRentInBillingMonth(transaction, DateTime(2026, 4, 1)), isFalse);
  });

  test('keeps previous month active before new invoices exist', () {
    final transactions = [
      _rent(year: 2026, month: 6, day: 30, status: 'pending'),
      _rent(year: 2026, month: 6, day: 30, status: 'completed'),
      _rent(year: 2026, month: 5, day: 30, status: 'pending'),
    ];

    final month = resolveActiveBillingMonth(
      transactions,
      referenceDate: DateTime(2026, 7, 1),
    );

    expect(month, DateTime(2026, 6, 1));
  });

  test('includes june pending rent in june financial summary on july 1', () {
    final transactions = [
      Transaction(
        id: 'june-invoice',
        assetId: 'asset-1',
        tenantId: 'tenant-1',
        amount: 9500,
        type: 'rent',
        status: 'pending',
        description: 'June 2026 invoice system entry',
        date: DateTime(2026, 4, 30).millisecondsSinceEpoch,
        createdAt: DateTime(2026, 4, 30).millisecondsSinceEpoch,
        updatedAt: DateTime(2026, 4, 30).millisecondsSinceEpoch,
      ),
    ];

    final activeMonth = resolveActiveBillingMonth(
      transactions,
      referenceDate: DateTime(2026, 7, 1),
    );
    final juneRent = rentTransactionsForBillingMonth(transactions, activeMonth);
    final pendingIncome = juneRent
        .where((transaction) => transaction.status == 'pending')
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    expect(activeMonth, DateTime(2026, 6, 1));
    expect(pendingIncome, 9500);
  });
}
