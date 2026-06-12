import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:landchg_tracker/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App renders bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const LandChgApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('地圖'), findsOneWidget);
    expect(find.text('清單'), findsOneWidget);
    expect(find.text('追蹤'), findsOneWidget);
    expect(find.text('資料'), findsOneWidget);
  });
}
