import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/point.dart';
import '../models/tracking.dart';

const _uuid = Uuid();

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'landchg.db');
    return openDatabase(
      path,
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE logs ADD COLUMN photos TEXT');
        }
        if (oldVersion < 3) {
          await _migrateToUuidKeys(db);
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE points (
            uid TEXT PRIMARY KEY,
            case_id TEXT NOT NULL,
            city TEXT NOT NULL,
            year INTEGER NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            verification TEXT NOT NULL,
            type TEXT NOT NULL,
            props TEXT NOT NULL
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_points_city_year ON points(city, year)');
        await db.execute('''
          CREATE TABLE datasets (
            city TEXT NOT NULL,
            year INTEGER NOT NULL,
            count INTEGER NOT NULL,
            fetched_at TEXT NOT NULL,
            PRIMARY KEY (city, year)
          )
        ''');
        await db.execute('''
          CREATE TABLE tracking (
            id TEXT PRIMARY KEY,
            point_uid TEXT NOT NULL UNIQUE,
            status TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE logs (
            id TEXT PRIMARY KEY,
            point_uid TEXT NOT NULL,
            status TEXT,
            note TEXT NOT NULL,
            created_at TEXT NOT NULL,
            photos TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_logs_point ON logs(point_uid)');
      },
    );
  }

  /// v3: tracking and logs move to UUID primary keys so user-generated
  /// records can be shared and merged between devices. Point records
  /// keep their government-issued natural key.
  static Future<void> _migrateToUuidKeys(Database db) async {
    await db.execute('ALTER TABLE tracking RENAME TO tracking_old');
    await db.execute('''
      CREATE TABLE tracking (
        id TEXT PRIMARY KEY,
        point_uid TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    for (final row in await db.query('tracking_old')) {
      await db.insert('tracking', {
        'id': _uuid.v4(),
        'point_uid': row['point_uid'],
        'status': row['status'],
        'updated_at': row['updated_at'],
      });
    }
    await db.execute('DROP TABLE tracking_old');

    await db.execute('ALTER TABLE logs RENAME TO logs_old');
    await db.execute('''
      CREATE TABLE logs (
        id TEXT PRIMARY KEY,
        point_uid TEXT NOT NULL,
        status TEXT,
        note TEXT NOT NULL,
        created_at TEXT NOT NULL,
        photos TEXT
      )
    ''');
    for (final row in await db.query('logs_old')) {
      await db.insert('logs', {
        'id': _uuid.v4(),
        'point_uid': row['point_uid'],
        'status': row['status'],
        'note': row['note'],
        'created_at': row['created_at'],
        'photos': row['photos'],
      });
    }
    await db.execute('DROP TABLE logs_old');
    await db.execute('CREATE INDEX idx_logs_point ON logs(point_uid)');
  }

  // ---- datasets / points ----

  Future<void> savePoints(
      String city, int year, List<ChangePoint> points) async {
    final d = await db;
    await d.transaction((txn) async {
      final batch = txn.batch();
      for (final p in points) {
        batch.insert('points', p.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      batch.insert(
        'datasets',
        {
          'city': city,
          'year': year,
          'count': points.length,
          'fetched_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    });
  }

  /// Deletes a dataset; points with tracking records are kept so the
  /// tracking history stays intact.
  Future<void> deleteDataset(String city, int year) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete(
        'points',
        where:
            'city = ? AND year = ? AND uid NOT IN (SELECT point_uid FROM tracking)',
        whereArgs: [city, year],
      );
      await txn.delete('datasets',
          where: 'city = ? AND year = ?', whereArgs: [city, year]);
    });
  }

  Future<List<Dataset>> getDatasets() async {
    final d = await db;
    final rows = await d.query('datasets', orderBy: 'year DESC, city ASC');
    return rows.map(Dataset.fromDbMap).toList();
  }

  Future<bool> hasDataset(String city, int year) async {
    final d = await db;
    final rows = await d.query('datasets',
        where: 'city = ? AND year = ?', whereArgs: [city, year], limit: 1);
    return rows.isNotEmpty;
  }

  Future<List<ChangePoint>> getPoints(String city, int year,
      {String? type}) async {
    final d = await db;
    final rows = await d.query(
      'points',
      where: type == null || type == 'all'
          ? 'city = ? AND year = ?'
          : 'city = ? AND year = ? AND type = ?',
      whereArgs: type == null || type == 'all'
          ? [city, year]
          : [city, year, type],
    );
    return rows.map(ChangePoint.fromDbMap).toList();
  }

  Future<ChangePoint?> getPoint(String uid) async {
    final d = await db;
    final rows =
        await d.query('points', where: 'uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : ChangePoint.fromDbMap(rows.first);
  }

  Future<List<String>> getTypes(String city, int year) async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT DISTINCT type FROM points WHERE city = ? AND year = ? ORDER BY type',
      [city, year],
    );
    return rows.map((r) => r['type'] as String).toList();
  }

  // ---- tracking ----

  Future<Tracking?> getTracking(String uid) async {
    final d = await db;
    final rows = await d.query('tracking',
        where: 'point_uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? null : Tracking.fromDbMap(rows.first);
  }

  Future<Set<String>> getTrackedUids() async {
    final d = await db;
    final rows = await d.query('tracking', columns: ['point_uid']);
    return rows.map((r) => r['point_uid'] as String).toSet();
  }

  Future<void> setTracking(String uid, TrackStatus status) async {
    final d = await db;
    // Upsert keyed on point_uid; keeps the existing UUID on update.
    await d.rawInsert('''
      INSERT INTO tracking (id, point_uid, status, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(point_uid) DO UPDATE SET
        status = excluded.status,
        updated_at = excluded.updated_at
    ''', [
      _uuid.v4(),
      uid,
      status.name,
      DateTime.now().toIso8601String(),
    ]);
  }

  Future<void> removeTracking(String uid) async {
    final d = await db;
    await d.delete('tracking', where: 'point_uid = ?', whereArgs: [uid]);
  }

  /// All tracked points joined with their tracking record.
  Future<List<(ChangePoint, Tracking)>> getTrackedPoints() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT p.*, t.status AS t_status, t.updated_at AS t_updated_at
      FROM tracking t JOIN points p ON p.uid = t.point_uid
      ORDER BY t.updated_at DESC
    ''');
    final result = <(ChangePoint, Tracking)>[];
    for (final row in rows) {
      final tracking = Tracking.fromDbMap({
        'point_uid': row['uid'],
        'status': row['t_status'],
        'updated_at': row['t_updated_at'],
      });
      if (tracking != null) {
        result.add((ChangePoint.fromDbMap(row), tracking));
      }
    }
    return result;
  }

  // ---- logs ----

  Future<void> addLog(LogEntry entry) async {
    final d = await db;
    await d.insert('logs', entry.toDbMap());
  }

  Future<List<LogEntry>> getLogs(String uid) async {
    final d = await db;
    final rows = await d.query('logs',
        where: 'point_uid = ?', whereArgs: [uid], orderBy: 'created_at DESC');
    return rows.map(LogEntry.fromDbMap).toList();
  }

  Future<LogEntry?> getLatestLog(String uid) async {
    final d = await db;
    final rows = await d.query('logs',
        where: 'point_uid = ?',
        whereArgs: [uid],
        orderBy: 'created_at DESC',
        limit: 1);
    return rows.isEmpty ? null : LogEntry.fromDbMap(rows.first);
  }

  // ---- export / import ----

  Future<List<Tracking>> getAllTracking() async {
    final d = await db;
    final rows = await d.query('tracking');
    return rows.map(Tracking.fromDbMap).whereType<Tracking>().toList();
  }

  Future<List<LogEntry>> getAllLogs() async {
    final d = await db;
    final rows = await d.query('logs', orderBy: 'created_at ASC');
    return rows.map(LogEntry.fromDbMap).toList();
  }

  Future<List<ChangePoint>> getPointsByUids(Iterable<String> uids) async {
    final d = await db;
    final result = <ChangePoint>[];
    final list = uids.toList();
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, i + 500 > list.length ? list.length : i + 500);
      final rows = await d.query('points',
          where: 'uid IN (${List.filled(chunk.length, '?').join(',')})',
          whereArgs: chunk);
      result.addAll(rows.map(ChangePoint.fromDbMap));
    }
    return result;
  }

  /// Merges shared data from another user. Points are inserted only if
  /// missing (the natural key is identical across users); tracking keeps
  /// whichever record is newer per point; logs are unioned by UUID.
  Future<({int tracking, int logs, int points})> mergeImport({
    required List<ChangePoint> points,
    required List<Tracking> tracking,
    required List<LogEntry> logs,
  }) async {
    final d = await db;
    var trackingMerged = 0, logsMerged = 0, pointsMerged = 0;
    await d.transaction((txn) async {
      for (final p in points) {
        // ignored inserts return 0 (ffi) or -1 (Android)
        final n = await txn.insert('points', p.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
        if (n > 0) pointsMerged++;
      }
      for (final t in tracking) {
        final existing = await txn.query('tracking',
            where: 'point_uid = ?', whereArgs: [t.pointUid], limit: 1);
        if (existing.isEmpty) {
          await txn.insert('tracking', t.toDbMap());
          trackingMerged++;
        } else {
          final current = DateTime.parse(existing.first['updated_at'] as String);
          if (t.updatedAt.isAfter(current)) {
            await txn.update(
                'tracking',
                {
                  'status': t.status.name,
                  'updated_at': t.updatedAt.toIso8601String(),
                },
                where: 'point_uid = ?',
                whereArgs: [t.pointUid]);
            trackingMerged++;
          }
        }
      }
      for (final log in logs) {
        final n = await txn.insert('logs', log.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
        if (n > 0) logsMerged++;
      }
    });
    return (tracking: trackingMerged, logs: logsMerged, points: pointsMerged);
  }
}
