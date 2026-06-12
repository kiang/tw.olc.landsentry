import 'package:flutter/material.dart';

/// User-assigned tracking status for a point.
enum TrackStatus {
  watching('追蹤中', Colors.orange, Icons.visibility),
  improved('已改善', Colors.green, Icons.check_circle),
  unchanged('無變化', Colors.blueGrey, Icons.remove_circle_outline),
  worsened('惡化中', Colors.red, Icons.warning),
  closed('已結案', Colors.grey, Icons.archive);

  final String label;
  final Color color;
  final IconData icon;
  const TrackStatus(this.label, this.color, this.icon);

  static TrackStatus? fromName(String? name) {
    if (name == null) return null;
    for (final s in TrackStatus.values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// Tracking record for one point.
class Tracking {
  final String pointUid;
  final TrackStatus status;
  final DateTime updatedAt;

  Tracking({
    required this.pointUid,
    required this.status,
    required this.updatedAt,
  });

  static Tracking? fromDbMap(Map<String, Object?> m) {
    final status = TrackStatus.fromName(m['status'] as String?);
    if (status == null) return null;
    return Tracking(
      pointUid: m['point_uid'] as String,
      status: status,
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }
}

/// One log entry in a point's tracking history.
class LogEntry {
  final int? id;
  final String pointUid;
  final TrackStatus? status;
  final String note;
  final DateTime createdAt;

  LogEntry({
    this.id,
    required this.pointUid,
    this.status,
    required this.note,
    required this.createdAt,
  });

  Map<String, Object?> toDbMap() => {
        'point_uid': pointUid,
        'status': status?.name,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  static LogEntry fromDbMap(Map<String, Object?> m) => LogEntry(
        id: m['id'] as int?,
        pointUid: m['point_uid'] as String,
        status: TrackStatus.fromName(m['status'] as String?),
        note: (m['note'] as String?) ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
