import 'package:flutter_test/flutter_test.dart';
import 'package:landsentry/db/database.dart';
import 'package:landsentry/models/point.dart';
import 'package:landsentry/models/tracking.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dir, 'landchg.db'));
  });

  test('tracking/logs use uuid keys and imports merge correctly', () async {
    final db = AppDatabase.instance;
    final point = ChangePoint(
      uid: '臺南市|115|TEST001',
      caseId: 'TEST001',
      city: '臺南市',
      year: 115,
      lat: 23.0,
      lng: 120.2,
      verification: '違規',
      type: '整地',
      props: {'變異點編號': 'TEST001'},
    );
    await db.savePoints('臺南市', 115, [point]);
    await db.setTracking(point.uid, TrackStatus.watching);
    final t1 = (await db.getTracking(point.uid))!;
    expect(t1.id.length, 36); // uuid v4

    final log = LogEntry(
      pointUid: point.uid,
      status: TrackStatus.watching,
      note: 'first',
      createdAt: DateTime(2026, 6, 1),
    );
    expect(log.id.length, 36);
    await db.addLog(log);

    // Simulate importing a friend's archive: the same point (skipped),
    // a duplicate log (skipped), a new log (added), newer tracking (updated).
    final imported = await db.mergeImport(
      points: [point],
      tracking: [
        Tracking(
          pointUid: point.uid,
          status: TrackStatus.improved,
          updatedAt: DateTime(2030),
        )
      ],
      logs: [
        log,
        LogEntry(
          pointUid: point.uid,
          status: TrackStatus.improved,
          note: 'from friend',
          createdAt: DateTime(2026, 6, 2),
        ),
      ],
    );
    expect(imported.points, 0);
    expect(imported.tracking, 1);
    expect(imported.logs, 1);

    final t2 = (await db.getTracking(point.uid))!;
    expect(t2.status, TrackStatus.improved);
    expect(t2.id, t1.id); // local uuid survives the status merge
    expect((await db.getLogs(point.uid)).length, 2);

    // Importing the exact same archive again must be a no-op.
    final again = await db.mergeImport(
      points: [point],
      tracking: [
        Tracking(
          pointUid: point.uid,
          status: TrackStatus.improved,
          updatedAt: DateTime(2030),
        )
      ],
      logs: [log],
    );
    expect(again.tracking, 0);
    expect(again.logs, 0);
  });
}
