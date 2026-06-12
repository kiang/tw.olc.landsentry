import 'package:flutter/material.dart';

import '../app_state.dart';
import '../constants.dart';
import '../db/database.dart';
import '../models/point.dart';
import '../widgets/dataset_picker.dart';
import 'detail_screen.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final AppState _state = AppState.instance;
  List<ChangePoint> _points = [];
  Set<String> _trackedUids = {};
  List<String> _types = [];
  bool _hasDataset = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _state.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _state.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final hasDataset = await db.hasDataset(_state.city, _state.year);
    final points = hasDataset
        ? await db.getPoints(_state.city, _state.year, type: _state.type)
        : <ChangePoint>[];
    final types =
        hasDataset ? await db.getTypes(_state.city, _state.year) : <String>[];
    final tracked = await db.getTrackedUids();
    if (!mounted) return;
    setState(() {
      _points = points;
      _types = types;
      _trackedUids = tracked;
      _hasDataset = hasDataset;
    });
  }

  List<ChangePoint> get _filtered {
    var list =
        _points.where(_state.verification.matches).toList();
    if (_search.isNotEmpty) {
      list = list
          .where((p) =>
              p.caseId.contains(_search) ||
              p.type.contains(_search) ||
              (p.props['權責單位'] ?? '').contains(_search))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('變異點清單')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DatasetFilterBar(types: _types),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜尋編號 / 類型 / 權責單位',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: !_hasDataset
                ? _buildEmpty('尚未下載 ${_state.city} ${_state.year}年 資料',
                    showDownload: true)
                : filtered.isEmpty
                    ? _buildEmpty('沒有符合條件的變異點')
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _buildTile(filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(ChangePoint p) {
    final color =
        p.isIllegal ? AppConstants.illegalColor : AppConstants.legalColor;
    final tracked = _trackedUids.contains(p.uid);
    return ListTile(
      leading: Icon(Icons.location_on, color: color, size: 32),
      title: Text(p.type),
      subtitle: Text(
          '編號 ${p.caseId}${(p.props['權責單位'] ?? '').isNotEmpty ? '・${p.props['權責單位']}' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tracked) const Icon(Icons.star, color: Colors.amber, size: 20),
          const SizedBox(width: 4),
          Text(p.verification.isEmpty ? '未知' : p.verification,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(uid: p.uid)),
      ),
    );
  }

  Widget _buildEmpty(String message, {bool showDownload = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.grey)),
          if (showDownload) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('立即下載'),
              onPressed: () => downloadDatasetWithProgress(
                  context, _state.city, _state.year),
            ),
          ],
        ],
      ),
    );
  }
}
