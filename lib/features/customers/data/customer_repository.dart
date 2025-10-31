import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logger.dart';
import '../../../core/providers.dart';
import '../../auth/domain/profile.dart';
import '../domain/customer.dart';
import 'local/customer_dao.dart';
import 'remote/customer_remote_service.dart';

final uuid = Uuid();

class CustomerRepository {
  CustomerRepository(this._dao, this._remote, this._logger);

  final CustomerDao _dao;
  final CustomerRemoteService _remote;
  final Logger _logger;

  Future<List<Customer>> loadCustomers(Profile profile) async {
    final isAdmin = profile.isAdmin;
    return _dao.fetchCustomers(collectorId: isAdmin ? null : profile.id);
  }

  Future<int> unsyncedCount(Profile profile) {
    final isAdmin = profile.isAdmin;
    return _dao.countUnsynced(collectorId: isAdmin ? null : profile.id);
  }

  Future<void> saveCustomer(Customer customer, Profile profile) async {
    final now = DateTime.now().toUtc();
    final id = customer.remoteId.isEmpty ? uuid.v4() : customer.remoteId;
    final toSave = customer.copyWith(
      remoteId: id,
      collectorId: customer.collectorId.isEmpty
          ? profile.id
          : customer.collectorId,
      updatedAt: now,
      createdAt: customer.createdAt.isAfter(now)
          ? customer.createdAt
          : customer.createdAt,
      syncedAt: null,
      isDirty: true,
    );
    await _dao.upsertCustomer(toSave);
  }

  Future<void> deleteCustomer(Customer customer) async {
    if (customer.localId == null && customer.remoteId.isEmpty) return;
    if (customer.localId != null) {
      await _dao.deleteLocally(customer.localId!);
    } else {
      await _dao.removeByRemoteIds([customer.remoteId]);
    }
  }

  Future<void> syncNow(Profile profile) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw const SyncException('No network connection');
    }

    final dirty = await _dao.fetchDirtyCustomers(
      collectorId: profile.isAdmin ? null : profile.id,
    );

    final deletedIds = dirty
        .where((customer) => customer.isDeleted && customer.remoteId.isNotEmpty)
        .map((customer) => customer.remoteId)
        .toList();

    final toUpsert = dirty.where((customer) => !customer.isDeleted).toList();

    if (toUpsert.isNotEmpty) {
      try {
        await _remote.upsertCustomers(toUpsert);
      } catch (error, stack) {
        _logger.e(
          'Failed to upsert customers',
          error: error,
          stackTrace: stack,
        );
        rethrow;
      }
    }

    if (deletedIds.isNotEmpty) {
      try {
        await _remote.deleteCustomers(deletedIds);
      } catch (error, stack) {
        _logger.e(
          'Failed to mark customers deleted',
          error: error,
          stackTrace: stack,
        );
        rethrow;
      }
    }

    final cursor = DateTime.now().toUtc();
    final remoteUpdates = await _remote.fetchCustomerUpdates(
      since: await _dao.readLastCursor(),
      includeDeleted: profile.isAdmin,
    );

    // Merge remote updates into local cache
    for (final customer in remoteUpdates) {
      final local = customer.copyWith(
        syncedAt: customer.syncedAt ?? cursor,
        isDirty: false,
        isDeleted: customer.isDeleted,
      );
      await _dao.upsertCustomer(local);
    }

    await _dao.markSynced(
      toUpsert.map((customer) => customer.remoteId),
      cursor,
    );

    await _dao.removeByRemoteIds(deletedIds);
    await _dao.saveLastCursor(cursor);
    await _dao.purgeSoftDeleted();
  }
}

class SyncException implements Exception {
  const SyncException(this.message);
  final String message;

  @override
  String toString() => 'SyncException: $message';
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final database = ref.watch(localDatabaseProvider);
  final dao = CustomerDao(database);
  final remote = ref.watch(customerRemoteServiceProvider);
  final logger = ref.watch(loggerProvider);
  return CustomerRepository(dao, remote, logger);
});

final customerRemoteServiceProvider = Provider<CustomerRemoteService>((ref) {
  final client = ref.watch(supabaseProvider);
  return CustomerRemoteService(client);
});
