import 'package:intl/intl.dart';

import '../models/transaction.dart';

bool isActiveRentTransaction(Transaction transaction) {
  return transaction.type.toLowerCase() == 'rent' &&
      transaction.status.toLowerCase() != 'cancelled';
}

DateTime monthStartFromTimestamp(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return DateTime(date.year, date.month, 1);
}

DateTime previousMonthStart(DateTime month) {
  return DateTime(month.year, month.month - 1, 1);
}

final RegExp _billingMonthPattern = RegExp(
  r'(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})',
  caseSensitive: false,
);

/// Uses the month named in descriptions such as "June 2026 invoice system entry"
/// or "April 2026 rent due". Falls back to the transaction date when absent.
DateTime resolveTransactionBillingMonth(Transaction transaction) {
  final description = transaction.description.trim();
  final match = _billingMonthPattern.firstMatch(description);
  if (match != null) {
    try {
      final parsed = DateFormat('MMMM yyyy')
          .parse('${match.group(1)} ${match.group(2)}');
      return DateTime(parsed.year, parsed.month, 1);
    } catch (_) {
      // Fall through to transaction date.
    }
  }

  return monthStartFromTimestamp(transaction.date);
}

bool isRentInBillingMonth(Transaction transaction, DateTime month) {
  if (!isActiveRentTransaction(transaction)) return false;

  final billingMonth = resolveTransactionBillingMonth(transaction);
  return billingMonth.year == month.year && billingMonth.month == month.month;
}

bool hasRentActivityInMonth(
  List<Transaction> transactions,
  DateTime month,
) {
  return transactions.any((transaction) => isRentInBillingMonth(transaction, month));
}

DateTime? _latestRentBillingMonth(List<Transaction> transactions) {
  DateTime? latestMonth;

  for (final transaction in transactions) {
    if (!isActiveRentTransaction(transaction)) continue;

    final billingMonth = resolveTransactionBillingMonth(transaction);
    if (latestMonth == null || billingMonth.isAfter(latestMonth)) {
      latestMonth = billingMonth;
    }
  }

  return latestMonth;
}

/// Keeps income stats on the latest invoiced month until the current month
/// has its own rent transactions (for example after July invoices are generated).
DateTime resolveActiveBillingMonth(
  List<Transaction> transactions, {
  DateTime? referenceDate,
}) {
  final now = referenceDate ?? DateTime.now();
  final currentMonth = DateTime(now.year, now.month, 1);

  if (hasRentActivityInMonth(transactions, currentMonth)) {
    return currentMonth;
  }

  final priorMonth = previousMonthStart(currentMonth);
  if (hasRentActivityInMonth(transactions, priorMonth)) {
    return priorMonth;
  }

  return _latestRentBillingMonth(transactions) ?? currentMonth;
}

List<Transaction> rentTransactionsForBillingMonth(
  List<Transaction> transactions,
  DateTime month,
) {
  return transactions
      .where((transaction) => isRentInBillingMonth(transaction, month))
      .toList();
}
