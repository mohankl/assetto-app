import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/tenant.dart';
import '../models/asset.dart';
import '../utils/currency_format.dart';

class TenantsScreen extends StatelessWidget {
  const TenantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Tenant',
            onPressed: () => _showAddTenantDialog(context),
          ),
        ],
      ),
      body: dataProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : dataProvider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${dataProvider.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => dataProvider.refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : dataProvider.tenants.isEmpty
                  ? const Center(
                      child: Text('No tenants found'),
                    )
                  : RefreshIndicator(
                      onRefresh: () => dataProvider.refresh(),
                      child: _buildGroupedTenants(context, dataProvider),
                    ),
    );
  }

  Widget _buildGroupedTenants(BuildContext context, DataProvider dataProvider) {
    // Group tenants by asset address
    final Map<String, List<Tenant>> groupedTenants = {};

    for (final tenant in dataProvider.tenants) {
      final asset = dataProvider.assets.firstWhere(
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

      final address = asset.address;
      if (!groupedTenants.containsKey(address)) {
        groupedTenants[address] = [];
      }
      groupedTenants[address]!.add(tenant);
    }

    return ListView.builder(
      itemCount: groupedTenants.length,
      itemBuilder: (context, index) {
        final address = groupedTenants.keys.elementAt(index);
        final tenants = groupedTenants[address]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Text(
              address,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: tenants
                .map((tenant) => _buildTenantCard(context, tenant))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildTenantCard(BuildContext context, Tenant tenant) {
    final dataProvider = context.read<DataProvider>();
    final asset = dataProvider.assets.firstWhere(
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

    final dateFormat = DateFormat('MMM d, y');
    final leaseEndDate = tenant.leaseEnd != null
        ? dateFormat
            .format(DateTime.fromMillisecondsSinceEpoch(tenant.leaseEnd!))
        : 'No end date';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              tenant.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(tenant.leaseEnd).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getStatusText(tenant.leaseEnd),
              style: TextStyle(
                color: _getStatusColor(tenant.leaseEnd),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.home, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Unit # ${asset.unitNumber}'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 16),
              const SizedBox(width: 8),
              Text(tenant.phone),
            ],
          ),
          if (tenant.remarks?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.note, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(tenant.remarks!)),
              ],
            ),
          ],
          if (tenant.aadharNumber?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.badge, size: 16),
                const SizedBox(width: 8),
                Text(tenant.aadharNumber!),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Text('Lease ending: $leaseEndDate'),
            ],
          ),
          if (tenant.advanceAmount != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.payments, size: 16),
                const SizedBox(width: 8),
                Text('Advance: ${formatCurrency(tenant.advanceAmount!, decimalDigits: 2)}'),
              ],
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(context, value, tenant),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Text('Edit'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int? leaseEnd) {
    if (leaseEnd == null) {
      return Colors.grey;
    }
    final now = DateTime.now();
    final endDate = DateTime.fromMillisecondsSinceEpoch(leaseEnd);
    if (endDate.isBefore(now)) {
      return Colors.red;
    } else if (endDate.isBefore(now.add(const Duration(days: 30)))) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getStatusText(int? leaseEnd) {
    if (leaseEnd == null) {
      return 'No lease';
    }
    final now = DateTime.now();
    final endDate = DateTime.fromMillisecondsSinceEpoch(leaseEnd);
    if (endDate.isBefore(now)) {
      return 'Expired';
    } else if (endDate.isBefore(now.add(const Duration(days: 30)))) {
      return 'Expiring soon';
    } else {
      return 'Active';
    }
  }

  void _handleMenuAction(BuildContext context, String action, Tenant tenant) {
    switch (action) {
      case 'edit':
        _showEditTenantDialog(context, tenant);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(context, tenant);
        break;
    }
  }

  Future<String?> _pickAndUploadAadharImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      final fileName = 'aadhar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('aadhar_images/$fileName');
      final bytes = await pickedFile.readAsBytes();

      if (!context.mounted) return null;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: $progress%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      Navigator.pop(context); // Close loading dialog
      return downloadUrl;
    } catch (e) {
      print('Error uploading Aadhar image: $e');
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _showAddTenantDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final remarksController = TextEditingController();
    final phoneController = TextEditingController();
    final aadharNumberController = TextEditingController();
    final advanceAmountController = TextEditingController();
    String? selectedAssetId;
    DateTime? leaseStartDate;
    DateTime? leaseEndDate;
    String? aadharImageUrl;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tenant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(labelText: 'Remarks'),
                maxLines: 3,
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone *'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: aadharNumberController,
                decoration: const InputDecoration(labelText: 'Aadhar Number'),
              ),
              const SizedBox(height: 16),
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
                  selectedAssetId = value;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: advanceAmountController,
                decoration: const InputDecoration(labelText: 'Advance Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) {
                          leaseStartDate = date;
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(leaseStartDate == null
                          ? 'Lease Start Date *'
                          : DateFormat('dd/MM/yyyy').format(leaseStartDate!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate:
                              leaseStartDate?.add(const Duration(days: 365)) ??
                                  DateTime.now().add(const Duration(days: 365)),
                          firstDate: leaseStartDate ?? DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) {
                          leaseEndDate = date;
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(leaseEndDate == null
                          ? 'Lease End Date *'
                          : DateFormat('dd/MM/yyyy').format(leaseEndDate!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final imageUrl = await _pickAndUploadAadharImage(context);
                  if (imageUrl != null) {
                    aadharImageUrl = imageUrl;
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Aadhar Image'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty ||
                  phoneController.text.isEmpty ||
                  selectedAssetId == null ||
                  leaseStartDate == null ||
                  leaseEndDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
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
                aadharImage: aadharImageUrl,
                assetId: selectedAssetId!,
                leaseStart: leaseStartDate!.millisecondsSinceEpoch,
                leaseEnd: leaseEndDate!.millisecondsSinceEpoch,
                advanceAmount: advanceAmountController.text.isEmpty
                    ? null
                    : double.parse(advanceAmountController.text),
                createdAt: DateTime.now().millisecondsSinceEpoch,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              );

              context.read<DataProvider>().addTenant(tenant);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditTenantDialog(
      BuildContext context, Tenant tenant) async {
    final nameController = TextEditingController(text: tenant.name);
    final remarksController = TextEditingController(text: tenant.remarks);
    final phoneController = TextEditingController(text: tenant.phone);
    final aadharNumberController =
        TextEditingController(text: tenant.aadharNumber);
    final advanceAmountController =
        TextEditingController(text: tenant.advanceAmount?.toString() ?? '');
    String selectedAssetId = tenant.assetId;
    DateTime? leaseStartDate = tenant.leaseStart != null
        ? DateTime.fromMillisecondsSinceEpoch(tenant.leaseStart!)
        : null;
    DateTime? leaseEndDate = tenant.leaseEnd != null
        ? DateTime.fromMillisecondsSinceEpoch(tenant.leaseEnd!)
        : null;
    String? aadharImageUrl = tenant.aadharImage;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tenant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(labelText: 'Remarks'),
                maxLines: 3,
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone *'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: aadharNumberController,
                decoration: const InputDecoration(labelText: 'Aadhar Number'),
              ),
              const SizedBox(height: 16),
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
                  if (value != null) {
                    selectedAssetId = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: advanceAmountController,
                decoration: const InputDecoration(labelText: 'Advance Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: leaseStartDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) {
                          leaseStartDate = date;
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(leaseStartDate == null
                          ? 'Lease Start Date *'
                          : DateFormat('dd/MM/yyyy').format(leaseStartDate!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: leaseEndDate ??
                              (leaseStartDate?.add(const Duration(days: 365)) ??
                                  DateTime.now()
                                      .add(const Duration(days: 365))),
                          firstDate: leaseStartDate ?? DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) {
                          leaseEndDate = date;
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(leaseEndDate == null
                          ? 'Lease End Date *'
                          : DateFormat('dd/MM/yyyy').format(leaseEndDate!)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final imageUrl = await _pickAndUploadAadharImage(context);
                  if (imageUrl != null) {
                    aadharImageUrl = imageUrl;
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Aadhar Image'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty ||
                  phoneController.text.isEmpty ||
                  selectedAssetId.isEmpty ||
                  leaseStartDate == null ||
                  leaseEndDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                  ),
                );
                return;
              }

              final updatedTenant = tenant.copyWith(
                name: nameController.text,
                remarks: remarksController.text.isEmpty
                    ? null
                    : remarksController.text,
                phone: phoneController.text,
                aadharNumber: aadharNumberController.text.isEmpty
                    ? null
                    : aadharNumberController.text,
                aadharImage: aadharImageUrl,
                assetId: selectedAssetId,
                leaseStart: leaseStartDate!.millisecondsSinceEpoch,
                leaseEnd: leaseEndDate!.millisecondsSinceEpoch,
                advanceAmount: advanceAmountController.text.isEmpty
                    ? null
                    : double.parse(advanceAmountController.text),
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              );

              context.read<DataProvider>().updateTenant(updatedTenant);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, Tenant tenant) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text('Are you sure you want to delete ${tenant.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<DataProvider>().deleteTenant(tenant.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
