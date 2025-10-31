import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/customer_controller.dart';
import '../domain/customer.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.existing});

  final Customer? existing;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _meterController;
  late final TextEditingController _accountController;
  late final TextEditingController _poleController;
  late final TextEditingController _planCodeController;

  PlanType _selectedPlan = PlanType.planA;
  PlanBUnit? _selectedPlanUnit;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.customerName ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _meterController = TextEditingController(text: existing?.meterNo ?? '');
    _accountController = TextEditingController(text: existing?.accountNo ?? '');
    _poleController = TextEditingController(text: existing?.poleNo ?? '');
    _planCodeController = TextEditingController(text: existing?.planCode ?? '');
    _selectedPlan = existing?.plan ?? PlanType.planA;
    _selectedPlanUnit = existing?.planUnit;
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _meterController.dispose();
    _accountController.dispose();
    _poleController.dispose();
    _planCodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = ref.read(customerFormControllerProvider);
    try {
      await controller.saveCustomer(
        localId: widget.existing?.localId?.toString(),
        remoteId: widget.existing?.remoteId,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        meterNo: _meterController.text.trim(),
        accountNo: _accountController.text.trim(),
        poleNo: _poleController.text.trim(),
        plan: _selectedPlan,
        planUnit: _selectedPlan == PlanType.planA ? null : _selectedPlanUnit,
        planCode: _planCodeController.text.trim().isEmpty
            ? null
            : _planCodeController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer saved locally. Sync to upload.'),
        ),
      );
    } on CustomerValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save customer: $error')),
      );
    }
  }

  Future<void> _captureCoordinates() async {
    final controller = ref.read(customerFormControllerProvider);
    try {
      final coordinate = await controller.captureCoordinate();
      if (!mounted || coordinate == null) return;
      setState(() {
        _latitude = coordinate.latitude;
        _longitude = coordinate.longitude;
      });
    } on CustomerValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture coordinates: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add Customer' : 'Edit Customer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Customer name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _meterController,
                decoration: const InputDecoration(labelText: 'Meter number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountController,
                decoration: const InputDecoration(labelText: 'Account number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _poleController,
                decoration: const InputDecoration(labelText: 'Pole number'),
              ),
              const SizedBox(height: 20),
              Text('Plan', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<PlanType>(
                segments: const [
                  ButtonSegment(value: PlanType.planA, label: Text('Plan A')),
                  ButtonSegment(value: PlanType.planB, label: Text('Plan B')),
                ],
                selected: {_selectedPlan},
                onSelectionChanged: (value) {
                  setState(() {
                    _selectedPlan = value.first;
                    if (_selectedPlan == PlanType.planA) {
                      _selectedPlanUnit = null;
                    }
                  });
                },
              ),
              if (_selectedPlan == PlanType.planB) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<PlanBUnit>(
                  initialValue: _selectedPlanUnit,
                  items: const [
                    DropdownMenuItem(
                      value: PlanBUnit.unitOne,
                      child: Text('Unit One'),
                    ),
                    DropdownMenuItem(
                      value: PlanBUnit.unitTwo,
                      child: Text('Unit Two'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedPlanUnit = value),
                  decoration: const InputDecoration(labelText: 'Plan B units'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _planCodeController,
                decoration: const InputDecoration(
                  labelText: 'Plan code (optional)',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _latitude == null
                          ? 'No coordinates captured'
                          : 'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _captureCoordinates,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Capture location'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.save),
                label: Text(
                  widget.existing == null ? 'Save customer' : 'Update customer',
                ),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
