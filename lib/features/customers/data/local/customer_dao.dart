import 'package:sqflite/sqflite.dart';

import '../../domain/customer.dart';
import '../../../../core/database/local_database.dart';

class CustomerDao {
  CustomerDao(this._localDatabase);

  final LocalDatabase _localDatabase;

  Database get _db => _localDatabase.database;

  Future<List<Customer>> fetchCustomers({String? collectorId}) async {
    final rows = await _db.query(
      'customers',
      where: collectorId != null
          ? 'collector_id = ? AND is_deleted = 0'
          : 'is_deleted = 0',
      whereArgs: collectorId != null ? [collectorId] : null,
      orderBy: 'updated_at DESC',
    );
    return rows.map(Customer.fromLocalMap).toList();
  }

  Future<List<Customer>> fetchDirtyCustomers({String? collectorId}) async {
    final rows = await _db.query(
      'customers',
      where: collectorId != null
          ? 'is_dirty = 1 AND collector_id = ?'
          : 'is_dirty = 1',
      whereArgs: collectorId != null ? [collectorId] : null,
    );
    return rows.map(Customer.fromLocalMap).toList();
  }

  Future<void> upsertCustomer(Customer customer) async {
    await _db.insert(
      'customers',
      customer.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markSynced(Iterable<String> remoteIds, DateTime syncedAt) async {
    final batch = _db.batch();
    for (final id in remoteIds) {
      batch.update(
        'customers',
        {
          'synced_at': syncedAt.toIso8601String(),
          'is_dirty': 0,
          'updated_at': syncedAt.toIso8601String(),
          'is_deleted': 0,
        },
        where: 'remote_id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeByRemoteIds(Iterable<String> remoteIds) async {
    final batch = _db.batch();
    for (final id in remoteIds) {
      batch.update(
        'customers',
        {
          'is_deleted': 1,
          'is_dirty': 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'remote_id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> purgeSoftDeleted() async {
    await _db.delete('customers', where: 'is_deleted = 1 AND is_dirty = 0');
  }

  Future<int> countUnsynced({String? collectorId}) async {
    final rows = Sqflite.firstIntValue(
      await _db.rawQuery(
        collectorId != null
            ? 'SELECT COUNT(*) FROM customers WHERE is_dirty = 1 AND collector_id = ?'
            : 'SELECT COUNT(*) FROM customers WHERE is_dirty = 1',
        collectorId != null ? [collectorId] : null,
      ),
    );
    return rows ?? 0;
  }

  Future<void> deleteLocally(int localId) async {
    await _db.update(
      'customers',
      {
        'is_deleted': 1,
        'is_dirty': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> saveLastCursor(DateTime cursor) async {
    await _db.insert('device_state', {
      'key': 'last_pull_cursor',
      'value': cursor.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DateTime?> readLastCursor() async {
    final rows = await _db.query(
      'device_state',
      where: 'key = ?',
      whereArgs: ['last_pull_cursor'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String?;
    if (value == null) return null;
    return DateTime.tryParse(value);
  }
}
