import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../controllers/customer_controller.dart';
import '../controllers/sync_controller.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';
import '../providers.dart';
import 'customer_form_screen.dart';
import 'widgets/sync_status_badge.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customerListProvider);
    final authState = ref.watch(authControllerProvider).value;
    final profile = authState?.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          if (profile?.isAdmin == true) ...[
            IconButton(
              tooltip: 'Refresh from Supabase',
              icon: const Icon(Icons.cloud_sync_outlined),
              onPressed: () async {
                final syncController = ref.read(syncControllerProvider);
                try {
                  await syncController.sync();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Latest cloud data synced locally.'),
                      ),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cloud sync failed: $error')),
                    );
                  }
                }
              },
            ),
            IconButton(
              tooltip: 'Export to Excel',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: () => _exportCustomers(context, ref, profile!),
            ),
          ],
          const SyncStatusBadge(),
        ],
      ),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No customers found locally.',
                      textAlign: TextAlign.center,
                    ),
                    if (profile?.isAdmin == true) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('Sync from Supabase'),
                        onPressed: () async {
                          final syncController = ref.read(
                            syncControllerProvider,
                          );
                          try {
                            await syncController.sync();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cloud customers synced.'),
                                ),
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Sync failed: $error')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: customers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return _CustomerCard(customer: customer);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load customers: $error'),
          ),
        ),
      ),
      floatingActionButton: profile?.isAdmin == true
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
                );
                ref.invalidate(customerListProvider);
                ref.invalidate(unsyncedCountProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Customer'),
            ),
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  const _CustomerCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerFormScreen(existing: customer),
            ),
          );
          ref.invalidate(customerListProvider);
          ref.invalidate(unsyncedCountProvider);
        },
        title: Text(customer.customerName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer.address),
            Text('Meter: ${customer.meterNo} · Account: ${customer.accountNo}'),
            if (customer.plan == PlanType.planB && customer.planUnit != null)
              Text('Plan ${customer.plan.label} / ${customer.planUnit!.label}')
            else
              Text('Plan ${customer.plan.label}'),
            if (customer.latitude != null && customer.longitude != null)
              Text('Location: ${customer.latitude}, ${customer.longitude}'),
            if (customer.isDirty)
              const Text(
                'Pending sync',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final controller = ref.read(customerFormControllerProvider);
            await controller.repository.deleteCustomer(customer);
            ref.invalidate(customerListProvider);
            ref.invalidate(unsyncedCountProvider);
          },
        ),
      ),
    );
  }
}

Future<void> _exportCustomers(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final repo = ref.read(customerRepositoryProvider);
  try {
    final customers = await repo.loadCustomers(profile);
    if (customers.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No customers to export.')),
        );
      }
      return;
    }

    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Customers';
    final sheet = excel[sheetName];
    sheet.appendRow(<CellValue?>[
      TextCellValue('Customer Name'),
      TextCellValue('Address'),
      TextCellValue('Phone'),
      TextCellValue('Email'),
      TextCellValue('Meter No'),
      TextCellValue('Account No'),
      TextCellValue('Pole No'),
      TextCellValue('Plan'),
      TextCellValue('Plan Unit'),
      TextCellValue('Plan Code'),
      TextCellValue('Latitude'),
      TextCellValue('Longitude'),
      TextCellValue('Created At'),
      TextCellValue('Updated At'),
      TextCellValue('Synced At'),
      TextCellValue('Collector'),
      TextCellValue('Is Deleted'),
    ]);

    for (final customer in customers) {
      sheet.appendRow(<CellValue?>[
        TextCellValue(customer.customerName),
        TextCellValue(customer.address),
        TextCellValue(customer.phone),
        TextCellValue(customer.email ?? ''),
        TextCellValue(customer.meterNo),
        TextCellValue(customer.accountNo),
        TextCellValue(customer.poleNo),
        TextCellValue(customer.plan.label),
        TextCellValue(customer.planUnit?.label ?? ''),
        TextCellValue(customer.planCode ?? ''),
        TextCellValue(customer.latitude?.toString() ?? ''),
        TextCellValue(customer.longitude?.toString() ?? ''),
        TextCellValue(customer.createdAt.toIso8601String()),
        TextCellValue(customer.updatedAt.toIso8601String()),
        TextCellValue(customer.syncedAt?.toIso8601String() ?? ''),
        TextCellValue(customer.collectorId),
        TextCellValue(customer.isDeleted ? 'Yes' : 'No'),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'customers_$timestamp.xlsx';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([
      XFile(
        file.path,
        name: fileName,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    ], text: 'Customer export generated on $timestamp');
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }
}
