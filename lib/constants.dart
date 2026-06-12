import 'package:flutter/material.dart';

class AppConstants {
  static const String dataUrl =
      'https://kiang.github.io/landchg.tcd.gov.tw/csv/points';

  static const List<String> cities = [
    '基隆市', '臺北市', '新北市', '桃園市', '新竹縣', '新竹市', '苗栗縣',
    '臺中市', '南投縣', '彰化縣', '雲林縣', '嘉義縣', '嘉義市', '臺南市',
    '高雄市', '屏東縣', '宜蘭縣', '花蓮縣', '臺東縣', '金門縣', '澎湖縣', '連江縣',
  ];

  /// Current year in ROC era (民國).
  static int get currentRocYear => DateTime.now().year - 1911;

  /// Available data years, newest first (data starts at ROC 93).
  static List<int> get years =>
      [for (int y = currentRocYear; y >= 93; y--) y];

  static const String defaultCity = '臺南市';

  // NLSC WMTS base layers (國土測繪圖資服務雲)
  static const String nlscEmapUrl =
      'https://wmts.nlsc.gov.tw/wmts/EMAP/default/GoogleMapsCompatible/{z}/{y}/{x}';
  static const String nlscPhotoUrl =
      'https://wmts.nlsc.gov.tw/wmts/PHOTO2/default/GoogleMapsCompatible/{z}/{y}/{x}';
  static const String nlscAttribution = '© 國土測繪圖資服務雲';

  static const Color illegalColor = Color(0xFFE74C3C);
  static const Color legalColor = Color(0xFF2980B9);
}
