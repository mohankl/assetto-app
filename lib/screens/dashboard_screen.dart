import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import '../models/tenant.dart';
import '../models/asset.dart';
import '../models/transaction.dart';
import '../utils/currency_format.dart';
import '../utils/billing_month.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<void> _refreshData() async {
    await context.read<DataProvider>().refresh();
  }

  // Get statistics for a specific month
  Map<String, dynamic> _getMonthlyStatistics(DateTime month) {
    final dataProvider = context.read<DataProvider>();
    final assets = dataProvider.assets;
    final tenants = dataProvider.tenants;
    final transactions = dataProvider.transactions;

    // Calculate statistics for the specific month
    final occupiedUnits = assets
        .where((asset) => asset.status.toLowerCase() == 'occupied')
        .length;
    final totalUnits = assets.length;
    final occupancyRate = totalUnits > 0
        ? (occupiedUnits / totalUnits * 100).toStringAsFixed(1)
        : '0';

    final upcomingLeaseEnds = tenants
        .where(
          (tenant) =>
              tenant.leaseEnd != null &&
              DateTime.fromMillisecondsSinceEpoch(tenant.leaseEnd!)
                  .isBefore(DateTime.now().add(const Duration(days: 30))),
        )
        .length;

    // Rent income uses the billing month from invoice descriptions, not only
    // the recorded transaction date (which can fall in a different month).
    final monthlyRentTransactions =
        rentTransactionsForBillingMonth(transactions, month);

    final receivedIncome = monthlyRentTransactions
        .where((t) => t.status.toLowerCase() == 'completed')
        .fold(0.0, (sum, t) => sum + t.amount);

    final pendingIncome = monthlyRentTransactions
        .where((t) => t.status.toLowerCase() == 'pending')
        .fold(0.0, (sum, t) => sum + t.amount);

    // Expected rent for the month equals outstanding plus collected amounts.
    final expectedIncome = pendingIncome + receivedIncome;

    final totalExpenses = transactions.where((t) {
      if (t.type.toLowerCase() != 'expense') return false;
      if (t.status.toLowerCase() == 'cancelled') return false;

      final transactionDate = DateTime.fromMillisecondsSinceEpoch(t.date);
      return transactionDate.year == month.year &&
          transactionDate.month == month.month;
    }).fold(0.0, (sum, t) => sum + t.amount);

    final monthlyTransactions = transactions.where((t) {
      if (t.status.toLowerCase() == 'cancelled') return false;
      if (t.type.toLowerCase() == 'rent') {
        return isRentInBillingMonth(t, month);
      }

      final transactionDate = DateTime.fromMillisecondsSinceEpoch(t.date);
      return transactionDate.year == month.year &&
          transactionDate.month == month.month;
    }).toList();

    // All outstanding pending rent dues across every month.
    final Map<String, List<dynamic>> unpaidTenantsWithTransactions = {};
    final Map<String, double> accumulatedPendingAmounts = {};
    final Map<String, List<Transaction>> pendingByTenantId = {};

    for (final transaction in transactions) {
      if (transaction.type.toLowerCase() != 'rent') continue;
      if (transaction.status.toLowerCase() != 'pending') continue;

      String tenantId = transaction.tenantId ?? '';
      if (tenantId.isEmpty) {
        final assetTenants =
            tenants.where((tenant) => tenant.assetId == transaction.assetId);
        if (assetTenants.length == 1) {
          tenantId = assetTenants.first.id;
        }
      }
      if (tenantId.isEmpty) continue;

      pendingByTenantId.putIfAbsent(tenantId, () => []).add(transaction);
    }

    for (final entry in pendingByTenantId.entries) {
      final tenant = tenants.firstWhere(
        (tenant) => tenant.id == entry.key,
        orElse: () => Tenant.empty(),
      );
      if (tenant.id.isEmpty) continue;

      final pendingTransactions = List<Transaction>.from(entry.value)
        ..sort((a, b) => a.date.compareTo(b.date));

      final asset = assets.firstWhere(
        (asset) => asset.id == tenant.assetId,
        orElse: () => Asset(
          id: '',
          name: 'Unknown Property',
          address: 'No address provided',
          type: 'Unknown',
          status: 'Unknown',
          unitNumber: '',
          rentAmount: 0.0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final accumulatedAmount =
          pendingTransactions.fold(0.0, (sum, t) => sum + t.amount);
      accumulatedPendingAmounts[tenant.id] = accumulatedAmount;

      unpaidTenantsWithTransactions.putIfAbsent(asset.address, () => []);
      unpaidTenantsWithTransactions[asset.address]!.add({
        'tenant': tenant,
        'asset': asset,
        'transactions': pendingTransactions,
        'accumulatedAmount': accumulatedAmount,
      });
    }

    for (final tenantsList in unpaidTenantsWithTransactions.values) {
      tenantsList.sort((a, b) {
        final nameA = (a['tenant'] as Tenant).name;
        final nameB = (b['tenant'] as Tenant).name;
        return nameA.compareTo(nameB);
      });
    }

    return {
      'occupiedUnits': occupiedUnits,
      'totalUnits': totalUnits,
      'occupancyRate': occupancyRate,
      'upcomingLeaseEnds': upcomingLeaseEnds,
      'unpaidTenantsWithTransactions': unpaidTenantsWithTransactions,
      'accumulatedPendingAmounts': accumulatedPendingAmounts,
      'receivedIncome': receivedIncome,
      'pendingIncome': pendingIncome,
      'expectedIncome': expectedIncome,
      'totalExpenses': totalExpenses,
      'monthlyTransactions': monthlyTransactions,
    };
  }

  // Build dashboard content for a specific month
  Widget _buildMonthlyDashboard(DateTime month) {
    final stats = _getMonthlyStatistics(month);

    final unpaidTenantsWithTransactions =
        stats['unpaidTenantsWithTransactions'] as Map<String, List<dynamic>>;
    final receivedIncome = stats['receivedIncome'] as double;
    final pendingIncome = stats['pendingIncome'] as double;
    final expectedIncome = stats['expectedIncome'] as double;
    final totalExpenses = stats['totalExpenses'] as double;
    final occupiedUnits = stats['occupiedUnits'] as int;
    final totalUnits = stats['totalUnits'] as int;
    final occupancyRate = stats['occupancyRate'] as String;
    final upcomingLeaseEnds = stats['upcomingLeaseEnds'] as int;

    // Calculate total accumulated unpaid amount
    final totalUnpaidAmount =
        unpaidTenantsWithTransactions.values.fold<double>(0.0, (sum, list) {
      return sum +
          list.fold<double>(0.0, (innerSum, tenantData) {
            return innerSum + (tenantData['accumulatedAmount'] as double);
          });
    });

    developer.log(
        'Dashboard Statistics for ${DateFormat('MMMM yyyy').format(month)}:');
    developer.log('Active billing month: ${DateFormat('MMMM yyyy').format(month)}');
    developer.log('Expected Income: $expectedIncome');
    developer.log('Pending Income: $pendingIncome');
    developer.log('Received Income: $receivedIncome');
    developer.log('Total Expenses: $totalExpenses');
    developer.log('Total Transactions: ${stats['monthlyTransactions'].length}');

    final currencyFormat = appCurrencyFormat(decimalDigits: 0);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(
            'Monthly Financial Summary',
            [
              _buildStatRow(
                'Expected Income',
                currencyFormat.format(expectedIncome),
                Icons.account_balance_wallet,
                color: Colors.teal,
              ),
              _buildStatRow(
                'Pending Income',
                currencyFormat.format(pendingIncome),
                Icons.pending_actions,
                color: Colors.orange,
              ),
              _buildStatRow(
                'Total Expenses',
                currencyFormat.format(totalExpenses),
                Icons.arrow_downward,
                color: Colors.red,
              ),
              _buildStatRow(
                'Received Income',
                currencyFormat.format(receivedIncome),
                Icons.account_balance,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            'Alerts',
            [
              Row(
                children: [
                  Expanded(
                    child: _buildStatRow(
                      'Unpaid Tenants',
                      '${unpaidTenantsWithTransactions.values.fold(0, (sum, list) => sum + list.length)}',
                      Icons.money_off,
                      color: unpaidTenantsWithTransactions.isNotEmpty
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                  if (unpaidTenantsWithTransactions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        currencyFormat.format(totalUnpaidAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
              if (unpaidTenantsWithTransactions.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                ...unpaidTenantsWithTransactions.keys.map((address) {
                  final tenantsList =
                      unpaidTenantsWithTransactions[address] as List<dynamic>;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              address,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${tenantsList.length} unpaid',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.only(left: 16.0),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Colors.red.withAlpha(100),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Column(
                          children: tenantsList.map((tenantData) {
                            final tenant = tenantData['tenant'] as Tenant;
                            final pendingTransactions =
                                tenantData['transactions'] as List<Transaction>;
                            final accumulatedAmount =
                                tenantData['accumulatedAmount'] as double;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withAlpha(10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              tenant.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              currencyFormat
                                                  .format(accumulatedAmount),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          tenant.phone.isNotEmpty
                                              ? tenant.phone
                                              : 'No phone number',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...pendingTransactions.map((transaction) {
                                          final dueDate =
                                              DateTime.fromMillisecondsSinceEpoch(
                                                  transaction.date);
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                left: 16.0, bottom: 4.0),
                                            padding: const EdgeInsets.all(8.0),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.orange.withAlpha(10),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        _pendingRentLabel(
                                                            transaction),
                                                        style:
                                                            const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Recorded: ${DateFormat('MMM d, yyyy').format(dueDate)}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  currencyFormat.format(
                                                      transaction.amount),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildStatRow(
                'Upcoming Lease Ends',
                upcomingLeaseEnds.toString(),
                Icons.warning,
                color: upcomingLeaseEnds > 0 ? Colors.orange : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            'Properties Overview',
            [
              _buildStatRow(
                'Total Properties',
                totalUnits.toString(),
                Icons.home,
              ),
              _buildStatRow(
                'Occupancy Rate',
                '$occupancyRate%',
                Icons.percent,
              ),
              _buildStatRow(
                'Occupied Units',
                occupiedUnits.toString(),
                Icons.people,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();
    final activeBillingMonth =
        resolveActiveBillingMonth(dataProvider.transactions);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        title: Text(
          'Asset Overview — ${DateFormat('MMMM yyyy').format(activeBillingMonth)}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: dataProvider.isLoading && !dataProvider.isInitialized
            ? const Center(child: CircularProgressIndicator())
            : dataProvider.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${dataProvider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.teal,
                            side: const BorderSide(color: Colors.teal),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _buildMonthlyDashboard(activeBillingMonth),
      ),
    );
  }

  Widget _buildSummaryCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: color ?? Theme.of(context).primaryColor,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String _pendingRentLabel(Transaction transaction) {
    if (transaction.description.trim().isNotEmpty) {
      return transaction.description.trim();
    }

    final dueDate = DateTime.fromMillisecondsSinceEpoch(transaction.date);
    return '${DateFormat('MMMM yyyy').format(dueDate)} rent due';
  }
}
