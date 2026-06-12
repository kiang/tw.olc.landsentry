import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../constants.dart';
import '../db/database.dart';
import '../models/point.dart';
import '../models/tracking.dart';
import '../services/location.dart';
import '../services/navigation.dart';
import '../services/photo_store.dart';

class DetailScreen extends StatefulWidget {
  final String uid;
  const DetailScreen({super.key, required this.uid});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  ChangePoint? _point;
  Tracking? _tracking;
  List<LogEntry> _logs = [];
  final TextEditingController _noteController = TextEditingController();
  TrackStatus _newStatus = TrackStatus.watching;
  final List<String> _pendingPhotos = [];
  bool _pickingPhoto = false;

  static const _importantFields = ['變異點編號', '變異類型', '查證結果', '變異點位置', '通報機關', '權責單位'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final name in _pendingPhotos) {
      PhotoStore.delete(name);
    }
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final point = await db.getPoint(widget.uid);
    final tracking = await db.getTracking(widget.uid);
    final logs = await db.getLogs(widget.uid);
    if (!mounted) return;
    setState(() {
      _point = point;
      _tracking = tracking;
      _logs = logs;
      if (tracking != null) _newStatus = tracking.status;
    });
  }

  Future<void> _saveLog() async {
    final note = _noteController.text.trim();
    final db = AppDatabase.instance;
    final statusChanged = _tracking?.status != _newStatus;
    if (note.isEmpty &&
        _pendingPhotos.isEmpty &&
        !statusChanged &&
        _tracking != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請輸入紀錄內容、附上照片或變更狀態')));
      return;
    }
    await db.setTracking(widget.uid, _newStatus);
    await db.addLog(LogEntry(
      pointUid: widget.uid,
      status: _newStatus,
      note: note.isEmpty
          ? (_tracking == null ? '開始追蹤' : '狀態更新為「${_newStatus.label}」')
          : note,
      createdAt: DateTime.now(),
      photos: List.of(_pendingPhotos),
    ));
    _pendingPhotos.clear();
    _noteController.clear();
    if (mounted) FocusScope.of(context).unfocus();
    AppState.instance.notifyDataChanged();
    await _load();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1920, imageQuality: 85);
      if (picked != null) {
        final name = await PhotoStore.import(picked);
        if (mounted) setState(() => _pendingPhotos.add(name));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('無法取得照片')));
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _removePending(String name) async {
    await PhotoStore.delete(name);
    if (mounted) setState(() => _pendingPhotos.remove(name));
  }

  void _viewPhoto(String name) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.file(File(PhotoStore.pathFor(name))),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoThumb(String name,
      {VoidCallback? onRemove, double size = 64}) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _viewPhoto(name),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(PhotoStore.pathFor(name)),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: size,
                height: size,
                color: Colors.black12,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _stopTracking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消追蹤'),
        content: const Text('確定要取消追蹤此點位嗎？歷史紀錄會保留。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('返回')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('取消追蹤')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppDatabase.instance.removeTracking(widget.uid);
    AppState.instance.notifyDataChanged();
    await _load();
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = _point;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('變異點詳細')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final color =
        p.isIllegal ? AppConstants.illegalColor : AppConstants.legalColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.type),
        actions: [
          if (_tracking != null)
            IconButton(
              icon: const Icon(Icons.star, color: Colors.amber),
              tooltip: '取消追蹤',
              onPressed: _stopTracking,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildMiniMap(p, color),
          const SizedBox(height: 12),
          _buildInfoCard(p, color),
          const SizedBox(height: 12),
          _buildExternalLinks(p),
          const SizedBox(height: 12),
          _buildTrackingCard(),
          const SizedBox(height: 12),
          _buildLogTimeline(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMiniMap(ChangePoint p, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(p.lat, p.lng),
            initialZoom: 16,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: AppConstants.nlscPhotoUrl,
              userAgentPackageName: 'tw.olc.landchg_tracker',
              maxZoom: 19,
            ),
            MarkerLayer(markers: [
              Marker(
                point: LatLng(p.lat, p.lng),
                width: 36,
                height: 36,
                alignment: Alignment.topCenter,
                child: Icon(Icons.location_on, color: color, size: 36),
              ),
            ]),
            const SimpleAttributionWidget(
              source: Text(AppConstants.nlscAttribution,
                  style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ChangePoint p, Color color) {
    final shown = <String>{};
    final rows = <Widget>[];

    void addRow(String label, String value, {bool highlight = false}) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Text(value,
                  style: highlight
                      ? TextStyle(color: color, fontWeight: FontWeight.bold)
                      : null),
            ),
          ],
        ),
      ));
    }

    for (final f in _importantFields) {
      final v = p.props[f] ?? '';
      if (v.isNotEmpty) {
        shown.add(f);
        addRow(f, v, highlight: f == '查證結果');
      }
    }
    for (final e in p.props.entries) {
      if (shown.contains(e.key) ||
          e.key == 'latitude' ||
          e.key == 'longitude' ||
          e.value.isEmpty) {
        continue;
      }
      addRow(e.key, e.value);
    }
    addRow('資料集', '${p.city} ${p.year}年');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('基本資料',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: '複製座標',
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: '${p.lat},${p.lng}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已複製座標')));
                  },
                ),
              ],
            ),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildExternalLinks(ChangePoint p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.navigation, size: 18),
              label: Builder(builder: (_) {
                final d = LocationService.distanceTo(p.lat, p.lng);
                return Text(d == null
                    ? '導航前往'
                    : '導航前往（約 ${LocationService.formatDistance(d)}）');
              }),
              onPressed: () => navigateToPoint(p.lat, p.lng),
            ),
            TextButton.icon(
              icon: const Icon(Icons.satellite_alt, size: 18),
              label: const Text('Google 衛星'),
              onPressed: () => _openUrl(
                  'https://www.google.com/maps/place/${p.lat},${p.lng}/@${p.lat},${p.lng},18z/data=!3m1!1e3'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.public, size: 18),
              label: const Text('Bing 衛星'),
              onPressed: () => _openUrl(
                  'https://www.bing.com/maps?cp=${p.lat}~${p.lng}&lvl=18&style=h'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('案件詳情'),
              onPressed: () => _openUrl(
                  'https://landchg.olc.tw/#detail/${p.caseId}?city=${Uri.encodeComponent(p.city)}&year=${p.year}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tracking == null ? '加入追蹤' : '更新追蹤狀態',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: TrackStatus.values.map((s) {
                return ChoiceChip(
                  avatar: Icon(s.icon,
                      size: 16,
                      color: _newStatus == s ? Colors.white : s.color),
                  label: Text(s.label,
                      style: TextStyle(
                          color: _newStatus == s ? Colors.white : null)),
                  selected: _newStatus == s,
                  selectedColor: s.color,
                  onSelected: (_) => setState(() => _newStatus = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: '紀錄現場觀察、處理進度...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera, size: 18),
                  label: const Text('拍照'),
                  onPressed: _pickingPhoto
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('相簿'),
                  onPressed: _pickingPhoto
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                ),
                if (_pickingPhoto) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
            if (_pendingPhotos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pendingPhotos
                      .map((name) => _photoThumb(name,
                          onRemove: () => _removePending(name)))
                      .toList(),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_task),
                label: Text(_tracking == null ? '開始追蹤' : '新增紀錄'),
                onPressed: _saveLog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTimeline() {
    if (_logs.isEmpty) return const SizedBox.shrink();
    final df = DateFormat('yyyy/MM/dd HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('追蹤紀錄 (${_logs.length})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._logs.map((log) {
              final status = log.status;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(status?.icon ?? Icons.notes,
                        color: status?.color ?? Colors.grey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.note),
                          if (log.photos.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: log.photos
                                    .map((name) => _photoThumb(name))
                                    .toList(),
                              ),
                            ),
                          Text(
                            '${status != null ? '${status.label}・' : ''}${df.format(log.createdAt)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
