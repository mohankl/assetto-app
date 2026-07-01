import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart' hide Asset;
import '../models/asset.dart';

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, child) {
        return dataProvider.isLoading
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
                : dataProvider.assets.isEmpty
                    ? const Center(
                        child: Text('No assets found'),
                      )
                    : RefreshIndicator(
                        onRefresh: () => dataProvider.loadAssets(),
                        child: _buildGroupedAssets(context, dataProvider),
                      );
      },
    );
  }

  Widget _buildGroupedAssets(BuildContext context, DataProvider dataProvider) {
    // Group assets by address
    final Map<String, List<Asset>> groupedAssets = {};

    for (final asset in dataProvider.assets) {
      final address = asset.address;
      if (!groupedAssets.containsKey(address)) {
        groupedAssets[address] = [];
      }
      groupedAssets[address]!.add(asset);
    }

    // Sort addresses alphabetically
    final sortedAddresses = groupedAssets.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedAddresses.length,
      itemBuilder: (context, index) {
        final address = sortedAddresses[index];
        final assets = groupedAssets[address]!;

        // Sort assets by unit number
        assets.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Row(
              children: [
                const Icon(Icons.location_on, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.teal.withAlpha(77),
                    ),
                  ),
                  child: Text(
                    '${assets.length} units',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.teal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            children: assets.map((asset) => AssetCard(asset: asset)).toList(),
          ),
        );
      },
    );
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
}

class AssetCard extends StatelessWidget {
  final Asset asset;

  const AssetCard({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unit ${asset.unitNumber}',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(asset.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                asset.status,
                style: TextStyle(
                  color: _getStatusColor(asset.status),
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
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(asset.address)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.category, size: 16),
                const SizedBox(width: 8),
                Text(asset.type),
                const SizedBox(width: 16),
                const Icon(Icons.payments, size: 16),
                const SizedBox(width: 8),
                Text('₹${asset.rentAmount.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value),
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
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'occupied':
        return Colors.green;
      case 'vacant':
        return Colors.orange;
      case 'under maintenance':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        _showEditAssetDialog(context);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(context);
        break;
    }
  }

  Future<void> _showEditAssetDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: asset.name);
    final addressController = TextEditingController(text: asset.address);
    final unitNumberController = TextEditingController(text: asset.unitNumber);
    final rentAmountController =
        TextEditingController(text: asset.rentAmount.toString());
    String selectedType = asset.type;
    String selectedStatus = asset.status;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Asset'),
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
                  context.read<DataProvider>().updateAsset(asset.id, assetData);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Asset'),
        content: Text('Are you sure you want to delete ${asset.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<DataProvider>().deleteAsset(asset.id);
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
