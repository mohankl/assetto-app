import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart' as firebase_db;
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'widgets/mobile_web_shell.dart';
import 'screens/dashboard_screen.dart';
import 'screens/assets_screen.dart';
import 'screens/tenants_screen.dart';
import 'screens/transactions_screen.dart';
import 'providers/data_provider.dart';
import 'package:intl/intl.dart';
import 'models/tenant.dart';
import 'models/transaction.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';

Future<void> initializeFirebase() async {
  try {
    developer.log('Starting Firebase initialization...', name: 'AppInit');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('Firebase initialization completed', name: 'AppInit');

    firebase_db.FirebaseDatabase.instance.databaseURL =
        DefaultFirebaseOptions.currentPlatform.databaseURL;
    developer.log('Database URL set successfully', name: 'AppInit');

    if (!kIsWeb) {
      firebase_db.FirebaseDatabase.instance.setPersistenceEnabled(true);
      firebase_db.FirebaseDatabase.instance
          .setPersistenceCacheSizeBytes(10000000);
      developer.log('Firebase settings configured successfully', name: 'AppInit');
    }

    // Enable performance monitoring and analytics
    FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    developer.log('Performance monitoring and analytics enabled',
        name: 'AppInit');

    // Test database connection with timeout
    final ref = firebase_db.FirebaseDatabase.instance.ref();
    try {
      await ref.child('test').get().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Database connection timed out');
        },
      );
      developer.log('Database connection successful', name: 'AppInit');
    } catch (e) {
      developer.log('Database connection test failed: $e', name: 'AppInit');
      // Don't rethrow here as this is just a test
    }

    // Enable offline persistence and prefetch critical data
    await prefetchCriticalData();
  } catch (e, stackTrace) {
    developer.log('Firebase initialization failed: $e\n$stackTrace',
        name: 'AppInit');
    rethrow;
  }
}

Future<void> prefetchCriticalData() async {
  try {
    developer.log('Prefetching critical data...');
    final ref = firebase_db.FirebaseDatabase.instance.ref();
    await Future.wait([
      ref.child('assets').keepSynced(true),
      ref.child('tenants').keepSynced(true),
      ref.child('transactions').keepSynced(true),
    ]);
    developer.log('Critical data prefetch completed');
  } catch (e, stackTrace) {
    developer.log('Error prefetching critical data: $e\n$stackTrace');
    // Don't rethrow here as this is not critical for app startup
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeFirebase();
    runApp(const MyApp());
  } catch (e) {
    developer.log('Failed to initialize app: $e');
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
      ],
      child: MaterialApp(
        title: 'Assetto',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return MobileWebShell(child: child ?? const SizedBox.shrink());
        },
        theme: ThemeData(
          primarySwatch: Colors.teal,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.teal,
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          tabBarTheme: const TabBarThemeData(
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.teal,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.teal),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.teal, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.teal),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          // Initialize data provider when authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<DataProvider>().initialize();
          });
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const AssetsScreen(),
    const TenantsScreen(),
    const TransactionsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    developer.log('MainScreen initialized');
  }

  void _onItemTapped(int index) {
    developer.log('Navigation item tapped: $index');
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleFloatingActionButton(BuildContext context) {
    switch (_selectedIndex) {
      case 1: // Assets
        _showAddAssetDialog(context);
        break;
      case 2: // Tenants
        _showAddTenantDialog(context);
        break;
      case 3: // Transactions
        _showAddTransactionDialog(context);
        break;
      default:
        // Do nothing for dashboard
        break;
    }
  }

  Future<void> _showAddAssetDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final unitNumberController = TextEditingController();
    final rentAmountController = TextEditingController();
    String selectedType = 'Apartment';
    String selectedStatus = 'Vacant';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Asset'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Address is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: unitNumberController,
                    decoration: const InputDecoration(labelText: 'Unit Number'),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Unit number is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: rentAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Rent Amount',
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Rent amount is required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: ['Apartment', 'House', 'Commercial', 'Other']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedType = value;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: ['Vacant', 'Occupied', 'Under Maintenance']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedStatus = value;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final assetData = {
                    'name': nameController.text,
                    'address': addressController.text,
                    'unit_number': unitNumberController.text,
                    'rent_amount': double.parse(rentAmountController.text),
                    'type': selectedType,
                    'status': selectedStatus,
                  };
                  context.read<DataProvider>().addAsset(assetData);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTenantDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final aadharNumberController = TextEditingController();
    final advanceAmountController = TextEditingController();
    final remarksController = TextEditingController();
    String? selectedAssetId;
    DateTime? leaseStart;
    DateTime? leaseEnd;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Tenant'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Basic Information
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Phone is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Property Selection
                  DropdownButtonFormField<String>(
                    value: selectedAssetId,
                    decoration: const InputDecoration(
                      labelText: 'Property *',
                      border: OutlineInputBorder(),
                    ),
                    items: context.read<DataProvider>().assets.map((asset) {
                      return DropdownMenuItem(
                        value: asset.id,
                        child: Text('${asset.name} - ${asset.unitNumber}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedAssetId = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a property' : null,
                  ),
                  const SizedBox(height: 16),

                  // Lease Dates
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (date != null) {
                              setState(() => leaseStart = date);
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            leaseStart == null
                                ? 'Start Date *'
                                : DateFormat('dd/MM/yyyy').format(leaseStart!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: leaseStart
                                      ?.add(const Duration(days: 365)) ??
                                  DateTime.now().add(const Duration(days: 365)),
                              firstDate: leaseStart ?? DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (date != null) {
                              setState(() => leaseEnd = date);
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            leaseEnd == null
                                ? 'End Date *'
                                : DateFormat('dd/MM/yyyy').format(leaseEnd!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Additional Information
                  TextFormField(
                    controller: aadharNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Aadhar Number',
                      border: OutlineInputBorder(),
                      helperText: 'Optional',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: advanceAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Advance Amount',
                      border: OutlineInputBorder(),
                      prefixText: '₹',
                      helperText: 'Optional',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder(),
                      helperText: 'Optional',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  if (leaseStart == null || leaseEnd == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select lease dates'),
                      ),
                    );
                    return;
                  }
                  if (selectedAssetId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a property'),
                      ),
                    );
                    return;
                  }
                  final tenant = Tenant(
                    id: '',
                    name: nameController.text,
                    remarks: remarksController.text.isEmpty
                        ? null
                        : remarksController.text,
                    phone: phoneController.text,
                    aadharNumber: aadharNumberController.text.isEmpty
                        ? null
                        : aadharNumberController.text,
                    aadharImage: null,
                    assetId: selectedAssetId!,
                    leaseStart: leaseStart!.millisecondsSinceEpoch,
                    leaseEnd: leaseEnd!.millisecondsSinceEpoch,
                    advanceAmount: advanceAmountController.text.isEmpty
                        ? null
                        : double.parse(advanceAmountController.text),
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                    updatedAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  context.read<DataProvider>().addTenant(tenant);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTransactionDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'advance';
    String selectedStatus = 'Pending';
    String? selectedAssetId;
    String? selectedTenantId;
    DateTime? transactionDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Transaction'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Amount is required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Description is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      value: selectedType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ['advance', 'expense', 'rent'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedType = newValue!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a type';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Pending', 'Completed', 'Failed']
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(
                                  status,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          selectedStatus = value;
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      value: selectedAssetId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Asset',
                        border: OutlineInputBorder(),
                      ),
                      items: context
                          .read<DataProvider>()
                          .assets
                          .map((asset) => DropdownMenuItem(
                                value: asset.id,
                                child: Text(
                                  '${asset.name} (${asset.unitNumber})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          selectedAssetId = value;
                        }
                      },
                      validator: (value) =>
                          value == null ? 'Please select an asset' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      value: selectedTenantId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tenant',
                        border: OutlineInputBorder(),
                      ),
                      items: context
                          .read<DataProvider>()
                          .tenants
                          .map((tenant) => DropdownMenuItem<String>(
                                value: tenant.id,
                                child: Text(
                                  tenant.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          selectedTenantId = value;
                        }
                      },
                      validator: (value) =>
                          value == null ? 'Please select a tenant' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(transactionDate == null
                        ? 'Select Date'
                        : 'Date: ${transactionDate.toString().split(' ')[0]}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => transactionDate = date);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  if (transactionDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a date'),
                      ),
                    );
                    return;
                  }
                  final transactionData = {
                    'amount': double.parse(amountController.text),
                    'description': descriptionController.text,
                    'type': selectedType,
                    'status': selectedStatus,
                    'asset_id': selectedAssetId,
                    'tenant_id': selectedTenantId,
                    'date': transactionDate!.millisecondsSinceEpoch,
                  };
                  context.read<DataProvider>().addTransaction(transactionData);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateMonthlyInvoices(BuildContext context) async {
    final dataProvider = context.read<DataProvider>();
    final now = DateTime.now();
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    // Get all assets with tenants
    final assetsWithTenants = dataProvider.assets.where((asset) {
      return dataProvider.tenants.any((tenant) => tenant.assetId == asset.id);
    }).toList();

    if (assetsWithTenants.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No assets with tenants found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      for (final asset in assetsWithTenants) {
        final tenant = dataProvider.tenants.firstWhere(
          (t) => t.assetId == asset.id,
          orElse: () => Tenant.empty(),
        );

        // Check if transaction already exists for this month
        final existingTransaction = dataProvider.transactions.firstWhere(
          (t) =>
              t.assetId == asset.id &&
              t.tenantId == tenant.id &&
              t.type.toLowerCase() == 'rent' &&
              DateTime.fromMillisecondsSinceEpoch(t.date).month == now.month &&
              DateTime.fromMillisecondsSinceEpoch(t.date).year == now.year,
          orElse: () => Transaction(
            id: '',
            assetId: '',
            tenantId: null,
            amount: 0.0,
            type: 'rent',
            status: 'pending',
            description: '',
            date: lastDayOfMonth.millisecondsSinceEpoch,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            additionalData: const {},
          ),
        );

        if (existingTransaction.id.isEmpty) {
          final transactionData = {
            'amount': asset.rentAmount,
            'asset_id': asset.id,
            'tenant_id': tenant.id,
            'type': 'rent',
            'status': 'pending',
            'description':
                '${DateFormat('MMMM yyyy').format(now)} invoice system entry',
            'date': lastDayOfMonth.millisecondsSinceEpoch,
          };
          await dataProvider.addTransaction(transactionData);
          developer.log(
              'Generated month-end transaction for asset: ${asset.name}, tenant: ${tenant.name}');
        } else {
          developer.log(
              'Month-end transaction already exists for asset: ${asset.name}, tenant: ${tenant.name}');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Monthly invoices generated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      developer.log('Error generating month-end transactions: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating invoices: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rollbackMonthlyInvoices(BuildContext context) async {
    final dataProvider = context.read<DataProvider>();
    final now = DateTime.now();

    try {
      // Find all transactions created by the invoice system for the current month
      final transactionsToDelete =
          dataProvider.transactions.where((transaction) {
        return transaction.type.toLowerCase() == 'rent' &&
            transaction.status.toLowerCase() == 'pending' &&
            transaction.description.contains(
                '${DateFormat('MMMM yyyy').format(now)} invoice system entry') &&
            DateTime.fromMillisecondsSinceEpoch(transaction.date).month ==
                now.month &&
            DateTime.fromMillisecondsSinceEpoch(transaction.date).year ==
                now.year;
      }).toList();

      if (transactionsToDelete.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No monthly invoices found to rollback'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Delete each transaction
      for (final transaction in transactionsToDelete) {
        await dataProvider.deleteTransaction(transaction.id);
        developer.log('Rolled back transaction: ${transaction.id}');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Successfully rolled back ${transactionsToDelete.length} monthly invoices'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      developer.log('Error rolling back monthly invoices: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rolling back invoices: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    developer.log('Building MainScreen with selected index: $_selectedIndex');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assetto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'generate_invoices') {
                _generateMonthlyInvoices(context);
              } else if (value == 'rollback_invoices') {
                _rollbackMonthlyInvoices(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'generate_invoices',
                child: Text('Generate Monthly Invoices'),
              ),
              const PopupMenuItem(
                value: 'rollback_invoices',
                child: Text('Rollback Monthly Invoices'),
              ),
            ],
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Assets',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Tenants',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Transactions',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? null
          : FloatingActionButton(
              onPressed: () => _handleFloatingActionButton(context),
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add),
            ),
    );
  }
}
