import '../models/transaction.dart';

bool isActiveRentTransaction(Transaction transaction) {
  return transaction.type.toLowerCase() == 'rent' &&
      transaction.status.toLowerCase() != 'cancelled';
}

DateTime monthStartFromTimestamp(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return DateTime(date.year, date.month, 1);
}

bool hasRentActivityInMonth(
  List<Transaction> transactions,
  DateTime month,
) {
  return transactions.any((transaction) {
    if (!isActiveRentTransaction(transaction)) return false;

    final transactionMonth = monthStartFromTimestamp(transaction.date);
    return transactionMonth.year == month.year &&
        transactionMonth.month == month.month;
  });
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

  DateTime? latestInvoicedMonth;
  for (final transaction in transactions) {
    if (!isActiveRentTransaction(transaction)) continue;

    final transactionMonth = monthStartFromTimestamp(transaction.date);
    if (latestInvoicedMonth == null ||
        transactionMonth.isAfter(latestInvoicedMonth)) {
      latestInvoicedMonth = transactionMonth;
    }
  }

  return latestInvoicedMonth ?? currentMonth;
}
