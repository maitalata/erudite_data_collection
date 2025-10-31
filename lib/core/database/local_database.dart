import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;

  static const _dbName = 'erudite_data.db';
  static const _dbVersion = 1;

  static Future<LocalDatabase> create() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, _dbName);

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (database, version) async {
        await _createSchema(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        await _migrate(database, oldVersion, newVersion);
      },
    );

    return LocalDatabase._(db);
  }

  static Future<void> _createSchema(Database database) async {
    await database.execute('''
      CREATE TABLE user_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        access_token TEXT NOT NULL,
        refresh_token TEXT,
        expires_at TEXT,
        profile_json TEXT,
        last_login TEXT
      );
    ''');

    await database.execute('''
      CREATE TABLE customers (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        collector_id TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        address TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        meter_no TEXT NOT NULL,
        account_no TEXT NOT NULL,
        pole_no TEXT NOT NULL,
        plan TEXT NOT NULL,
        plan_unit TEXT,
        plan_code TEXT,
        latitude REAL,
        longitude REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced_at TEXT,
        is_dirty INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        UNIQUE(remote_id)
      );
    ''');

    await database.execute(
      'CREATE INDEX idx_customers_collector ON customers(collector_id);',
    );
    await database.execute(
      'CREATE INDEX idx_customers_dirty ON customers(is_dirty);',
    );

    await database.execute('''
      CREATE TABLE device_state (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');
  }

  static Future<void> _migrate(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    // No migrations yet. Placeholder for future schema changes.
  }

  Database get database => _db;

  Future<void> close() => _db.close();
}
