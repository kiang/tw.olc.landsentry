import 'dart:convert';

/// A land-use change detection point (變異點).
class ChangePoint {
  final String uid; // "$city|$year|$caseId"
  final String caseId; // 變異點編號
  final String city;
  final int year; // ROC year
  final double lat;
  final double lng;
  final String verification; // 查證結果
  final String type; // 變異類型
  final Map<String, String> props; // all CSV fields

  ChangePoint({
    required this.uid,
    required this.caseId,
    required this.city,
    required this.year,
    required this.lat,
    required this.lng,
    required this.verification,
    required this.type,
    required this.props,
  });

  bool get isIllegal => verification == '違規';

  static ChangePoint? fromCsvRow(
      String city, int year, Map<String, String> row) {
    final caseId = row['變異點編號'] ?? '';
    final lat = double.tryParse(row['latitude'] ?? '');
    final lng = double.tryParse(row['longitude'] ?? '');
    if (caseId.isEmpty || lat == null || lng == null) return null;
    var type = (row['變異類型'] ?? '').trim();
    if (type.isEmpty) type = '其他';
    return ChangePoint(
      uid: '$city|$year|$caseId',
      caseId: caseId,
      city: city,
      year: year,
      lat: lat,
      lng: lng,
      verification: (row['查證結果'] ?? '').trim(),
      type: type,
      props: row,
    );
  }

  Map<String, Object?> toDbMap() => {
        'uid': uid,
        'case_id': caseId,
        'city': city,
        'year': year,
        'lat': lat,
        'lng': lng,
        'verification': verification,
        'type': type,
        'props': jsonEncode(props),
      };

  static ChangePoint fromDbMap(Map<String, Object?> m) => ChangePoint(
        uid: m['uid'] as String,
        caseId: m['case_id'] as String,
        city: m['city'] as String,
        year: m['year'] as int,
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        verification: m['verification'] as String,
        type: m['type'] as String,
        props: (jsonDecode(m['props'] as String) as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
}

/// A downloaded dataset (one city + year combination).
class Dataset {
  final String city;
  final int year;
  final int count;
  final DateTime fetchedAt;

  Dataset({
    required this.city,
    required this.year,
    required this.count,
    required this.fetchedAt,
  });

  static Dataset fromDbMap(Map<String, Object?> m) => Dataset(
        city: m['city'] as String,
        year: m['year'] as int,
        count: m['count'] as int,
        fetchedAt: DateTime.parse(m['fetched_at'] as String),
      );
}
