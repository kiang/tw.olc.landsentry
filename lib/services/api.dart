import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../db/database.dart';
import '../models/point.dart';

class ApiService {
  /// Downloads the CSV for one city/year and stores it locally.
  /// Returns the number of points saved. Returns 0 when the dataset
  /// exists but is empty; throws on network errors.
  static Future<int> downloadDataset(String city, int year) async {
    final url = Uri.parse(
        '${AppConstants.dataUrl}/$year/${Uri.encodeComponent(city)}.csv');
    final res = await http.get(url);
    if (res.statusCode == 404) {
      await AppDatabase.instance.savePoints(city, year, []);
      return 0;
    }
    if (res.statusCode != 200) {
      throw Exception('下載失敗 (HTTP ${res.statusCode})');
    }

    var text = utf8.decode(res.bodyBytes);
    if (text.startsWith('﻿')) text = text.substring(1);
    text = text.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) {
      await AppDatabase.instance.savePoints(city, year, []);
      return 0;
    }

    final rows = const CsvDecoder().convert(text);
    if (rows.length < 2) {
      await AppDatabase.instance.savePoints(city, year, []);
      return 0;
    }

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final points = <ChangePoint>[];
    for (final row in rows.skip(1)) {
      final map = <String, String>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i].toString();
      }
      final p = ChangePoint.fromCsvRow(city, year, map);
      if (p != null) points.add(p);
    }

    await AppDatabase.instance.savePoints(city, year, points);
    return points.length;
  }
}
