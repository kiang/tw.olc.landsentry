import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/download_screen.dart';
import 'screens/list_screen.dart';
import 'screens/map_screen.dart';
import 'screens/tracked_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LandChgApp());
}

class LandChgApp extends StatelessWidget {
  const LandChgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '國土監測追蹤',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    AppState.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          MapScreen(),
          ListScreen(),
          TrackedScreen(),
          DownloadScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: '地圖'),
          NavigationDestination(icon: Icon(Icons.list), label: '清單'),
          NavigationDestination(icon: Icon(Icons.star), label: '追蹤'),
          NavigationDestination(icon: Icon(Icons.cloud_download), label: '資料'),
        ],
      ),
    );
  }
}
