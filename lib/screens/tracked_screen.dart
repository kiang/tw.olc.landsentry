import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../constants.dart';
import '../db/database.dart';
import '../models/point.dart';
import '../models/tracking.dart';
import 'detail_screen.dart';

class TrackedScreen extends StatefulWidget {
  const TrackedScreen({super.key});

  @override
  State<TrackedScreen> createState() => _TrackedScreenState();
}

class _TrackedScreenState extends State<TrackedScreen> {
  final AppState _state = AppState.instance;
  List<(ChangePoint, Tracking)> _items = [];
  final Map<String, LogEntry?> _latestLogs = {};
  TrackStatus? _filter;

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
    final items = await db.getTrackedPoints();
    _latestLogs.clear();
    for (final (p, _) in items) {
      _latestLogs[p.uid] = await db.getLatestLog(p.uid);
    }
    if (!mounted) return;
    setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == null
        ? _items
        : _items.where((it) => it.$2.status == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('追蹤中的點位')),
      body: Column(
        children: [
          // status filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                ChoiceChip(
                  label: Text('全部 (${_items.length})'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                ...TrackStatus.values.map((s) {
                  final count =
                      _items.where((it) => it.$2.status == s).length;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      avatar: Icon(s.icon, size: 16, color: s.color),
                      label: Text('${s.label} ($count)'),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_border, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('尚無追蹤點位\n從地圖或清單點選變異點後加入追蹤',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final (p, t) = filtered[i];
                      return _buildTile(p, t);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(ChangePoint p, Tracking t) {
    final color =
        p.isIllegal ? AppConstants.illegalColor : AppConstants.legalColor;
    final latest = _latestLogs[p.uid];
    final df = DateFormat('yyyy/MM/dd HH:mm');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.location_on, color: color, size: 32),
        title: Text('${p.type}・${p.caseId}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.city} ${p.year}年'),
            if (latest != null && latest.note.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text('最新紀錄：${latest.note}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (latest.photos.isNotEmpty) ...[
                    const Icon(Icons.photo_camera,
                        size: 14, color: Colors.grey),
                    Text(' ${latest.photos.length}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ],
              ),
            Text(df.format(t.updatedAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Chip(
          avatar: Icon(t.status.icon, size: 16, color: Colors.white),
          label: Text(t.status.label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          backgroundColor: t.status.color,
          visualDensity: VisualDensity.compact,
        ),
        isThreeLine: true,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(uid: p.uid)),
        ),
      ),
    );
  }
}
