import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import '../models/tenant.dart';
import '../models/asset.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

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

    // Calculate income and expenses for the specific month (excluding cancelled transactions)
    final monthlyTransactions = transactions.where((t) {
      final transactionDate = DateTime.fromMillisecondsSinceEpoch(t.date);
      return transactionDate.year == month.year &&
          transactionDate.month == month.month &&
          t.status.toLowerCase() != 'cancelled';
    }).toList();

    final totalIncome = monthlyTransactions
        .where((t) => t.type.toLowerCase() == 'rent')
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalExpenses = monthlyTransactions
        .where((t) => t.type.toLowerCase() == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    final netIncome = totalIncome - totalExpenses;

    // Calculate expected cash flow (sum of all property rent amounts)
    final expectedCashFlow =
        assets.fold(0.0, (sum, asset) => sum + asset.rentAmount);

    // Find unpaid tenants and their pending transactions (excluding cancelled transactions)
    final Map<String, List<dynamic>> unpaidTenantsWithTransactions = {};
    final Map<String, double> accumulatedPendingAmounts = {};

    for (final tenant in tenants) {
      if (tenant.assetId.isEmpty) continue;

      final pendingTransactions = transactions.where((t) {
        final transactionDate = DateTime.fromMillisecondsSinceEpoch(t.date);
        return t.tenantId == tenant.id &&
            t.type.toLowerCase() == 'rent' &&
            transactionDate
                .isBefore(DateTime(month.year, month.month + 1, 1)) &&
            t.status.toLowerCase() == 'pending' &&
            t.status.toLowerCase() != 'cancelled';
      }).toList();

      if (pendingTransactions.isNotEmpty) {
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

        if (!unpaidTenantsWithTransactions.containsKey(asset.address)) {
          unpaidTenantsWithTransactions[asset.address] = [];
        }
        unpaidTenantsWithTransactions[asset.address]!.add({
          'tenant': tenant,
          'asset': asset,
          'transactions': pendingTransactions,
          'accumulatedAmount': accumulatedAmount,
        });
      }
    }

    return {
      'occupiedUnits': occupiedUnits,
      'totalUnits': totalUnits,
      'occupancyRate': occupancyRate,
      'upcomingLeaseEnds': upcomingLeaseEnds,
      'unpaidTenantsWithTransactions': unpaidTenantsWithTransactions,
      'accumulatedPendingAmounts': accumulatedPendingAmounts,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'netIncome': netIncome,
      'monthlyTransactions': monthlyTransactions,
      'expectedCashFlow': expectedCashFlow,
    };
  }

  // Build dashboard content for a specific month
  Widget _buildMonthlyDashboard(DateTime month) {
    final stats = _getMonthlyStatistics(month);

    final unpaidTenantsWithTransactions =
        stats['unpaidTenantsWithTransactions'] as Map<String, List<dynamic>>;
    final totalIncome = stats['totalIncome'] as double;
    final totalExpenses = stats['totalExpenses'] as double;
    final netIncome = stats['netIncome'] as double;
    final occupiedUnits = stats['occupiedUnits'] as int;
    final totalUnits = stats['totalUnits'] as int;
    final occupancyRate = stats['occupancyRate'] as String;
    final upcomingLeaseEnds = stats['upcomingLeaseEnds'] as int;
    final expectedCashFlow = stats['expectedCashFlow'] as double;
    final pendingIncome = expectedCashFlow - totalIncome;

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
    developer.log('Expected Income: $expectedCashFlow');
    developer.log('Total Income: $totalIncome');
    developer.log('Pending Income: $pendingIncome');
    developer.log('Total Expenses: $totalExpenses');
    developer.log('Net Income: $netIncome');
    developer.log('Total Transactions: ${stats['monthlyTransactions'].length}');

    final currencyFormat = NumberFormat.currency(
      symbol: '₹',
      locale: 'en_IN',
      decimalDigits: 0,
    );

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
                currencyFormat.format(expectedCashFlow),
                Icons.account_balance_wallet,
                color: Colors.teal,
              ),
              _buildStatRow(
                'Total Income',
                currencyFormat.format(totalIncome),
                Icons.arrow_upward,
                color: Colors.green,
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
                'Net Income',
                currencyFormat.format(netIncome),
                Icons.account_balance,
                color: netIncome >= 0 ? Colors.green : Colors.red,
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
                            final asset = tenantData['asset'] as Asset;
                            final transactions =
                                tenantData['transactions'] as List;
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
                                          'Unit ${asset.unitNumber}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...transactions.map((transaction) {
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
                                              children: [
                                                Text(
                                                  DateFormat('MMM yyyy').format(
                                                    DateTime
                                                        .fromMillisecondsSinceEpoch(
                                                            transaction.date),
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
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
                                        }).toList(),
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        title: Text(
          'Asset Overview — ${DateFormat('MMMM yyyy').format(_currentMonth)}',
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
                : _buildMonthlyDashboard(_currentMonth),
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
}
