import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'models/point.dart';

/// App-wide state: currently selected dataset filters, shared by the
/// map and list screens, plus a change counter screens listen to for
/// refreshing after downloads / tracking updates.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  String _city = AppConstants.defaultCity;
  int _year = AppConstants.currentRocYear;
  String _type = 'all';
  VerificationFilter _verification = VerificationFilter.all;

  String get city => _city;
  int get year => _year;
  String get type => _type;
  VerificationFilter get verification => _verification;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _city = prefs.getString('city') ?? AppConstants.defaultCity;
    _year = prefs.getInt('year') ?? AppConstants.currentRocYear;
    notifyListeners();
  }

  Future<void> setDataset(String city, int year) async {
    if (city == _city && year == _year) return;
    _city = city;
    _year = year;
    _type = 'all';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', city);
    await prefs.setInt('year', year);
  }

  void setType(String type) {
    if (type == _type) return;
    _type = type;
    notifyListeners();
  }

  void setVerification(VerificationFilter v) {
    if (v == _verification) return;
    _verification = v;
    notifyListeners();
  }

  /// Call after any data change (download, delete, tracking, log) so
  /// listening screens reload from the database.
  void notifyDataChanged() => notifyListeners();
}
