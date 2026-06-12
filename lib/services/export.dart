import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database.dart';
import '../models/point.dart';
import '../models/tracking.dart';
import 'photo_store.dart';

typedef ImportSummary = ({int tracking, int logs, int points, int photos});

/// Exports the tracking database (tracking records, logs, referenced
/// points and photos) as a single zip archive, and imports such archives
/// back, merging records by UUID. Sharing goes through the system share
/// sheet (e.g. save to Google Drive); import reads a file picked from
/// any document provider (e.g. a Google Drive folder).
class ExportService {
  static const _format = 'landsentry-tracking';
  static const _formatVersion = 1;

  static Future<File> buildArchive() async {
    final db = AppDatabase.instance;
    final tracking = await db.getAllTracking();
    final logs = await db.getAllLogs();
    final pointUids = <String>{
      ...tracking.map((t) => t.pointUid),
      ...logs.map((l) => l.pointUid),
    };
    final points = await db.getPointsByUids(pointUids);

    final manifest = {
      'format': _format,
      'version': _formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'points': [
        for (final p in points)
          {
            'uid': p.uid,
            'case_id': p.caseId,
            'city': p.city,
            'year': p.year,
            'lat': p.lat,
            'lng': p.lng,
            'verification': p.verification,
            'type': p.type,
            'props': p.props,
          }
      ],
      'tracking': [
        for (final t in tracking)
          {
            'id': t.id,
            'point_uid': t.pointUid,
            'status': t.status.name,
            'updated_at': t.updatedAt.toIso8601String(),
          }
      ],
      'logs': [
        for (final l in logs)
          {
            'id': l.id,
            'point_uid': l.pointUid,
            'status': l.status?.name,
            'note': l.note,
            'created_at': l.createdAt.toIso8601String(),
            'photos': l.photos,
          }
      ],
    };

    final archive = Archive();
    final jsonBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('export.json', jsonBytes.length, jsonBytes));

    final photoNames = <String>{for (final l in logs) ...l.photos};
    for (final name in photoNames) {
      final f = File(PhotoStore.pathFor(name));
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile('photos/$name', bytes.length, bytes));
      }
    }

    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/landsentry_$stamp.zip');
    await out.writeAsBytes(ZipEncoder().encodeBytes(archive));
    return out;
  }

  /// Builds the archive and opens the system share sheet.
  static Future<void> exportAndShare() async {
    final file = await buildArchive();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/zip')],
      subject: '國土巡守隊資料',
    ));
  }

  /// Lets the user pick an exported archive (from Google Drive or any
  /// document provider) and merges it into the local database.
  /// Returns null when the user cancels the picker.
  static Future<ImportSummary?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return importArchive(File(path));
  }

  static Future<ImportSummary> importArchive(File file) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());

    ArchiveFile? manifestFile;
    final photoFiles = <String, ArchiveFile>{};
    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (entry.name == 'export.json') {
        manifestFile = entry;
      } else if (entry.name.startsWith('photos/')) {
        photoFiles[entry.name.substring('photos/'.length)] = entry;
      }
    }
    if (manifestFile == null) {
      throw const FormatException('找不到 export.json');
    }

    final manifest = jsonDecode(utf8.decode(manifestFile.content)) as Map;
    if (manifest['format'] != _format) {
      throw const FormatException('不是有效的追蹤資料檔');
    }

    final points = [
      for (final m in (manifest['points'] as List? ?? []))
        ChangePoint(
          uid: m['uid'] as String,
          caseId: m['case_id'] as String,
          city: m['city'] as String,
          year: (m['year'] as num).toInt(),
          lat: (m['lat'] as num).toDouble(),
          lng: (m['lng'] as num).toDouble(),
          verification: (m['verification'] as String?) ?? '',
          type: (m['type'] as String?) ?? '其他',
          props: ((m['props'] as Map?) ?? {})
              .map((k, v) => MapEntry(k.toString(), v.toString())),
        )
    ];
    final tracking = [
      for (final m in (manifest['tracking'] as List? ?? []))
        if (TrackStatus.fromName(m['status'] as String?) != null)
          Tracking(
            id: m['id'] as String?,
            pointUid: m['point_uid'] as String,
            status: TrackStatus.fromName(m['status'] as String?)!,
            updatedAt: DateTime.parse(m['updated_at'] as String),
          )
    ];
    final logs = [
      for (final m in (manifest['logs'] as List? ?? []))
        LogEntry(
          id: m['id'] as String?,
          pointUid: m['point_uid'] as String,
          status: TrackStatus.fromName(m['status'] as String?),
          note: (m['note'] as String?) ?? '',
          createdAt: DateTime.parse(m['created_at'] as String),
          photos: ((m['photos'] as List?) ?? [])
              .map((e) => e.toString())
              .toList(),
        )
    ];

    final counts = await AppDatabase.instance
        .mergeImport(points: points, tracking: tracking, logs: logs);

    var photosCopied = 0;
    for (final entry in photoFiles.entries) {
      // basename only: never let archive entries escape the photo dir
      final name = p.basename(entry.key);
      if (name.isEmpty || name.startsWith('.')) continue;
      final dest = File(PhotoStore.pathFor(name));
      if (!await dest.exists()) {
        await dest.writeAsBytes(entry.value.content);
        photosCopied++;
      }
    }

    return (
      tracking: counts.tracking,
      logs: counts.logs,
      points: counts.points,
      photos: photosCopied,
    );
  }
}
