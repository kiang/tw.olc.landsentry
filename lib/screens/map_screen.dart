import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../constants.dart';
import '../db/database.dart';
import '../models/point.dart';
import '../widgets/dataset_picker.dart';
import '../widgets/point_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final AppState _state = AppState.instance;

  List<ChangePoint> _points = [];
  Set<String> _illegalUids = {};
  Set<String> _trackedUids = {};
  List<String> _types = [];
  bool _hasDataset = true;
  bool _loading = true;
  bool _usePhotoLayer = false;
  bool _mapReady = false;
  String _loadedKey = '';

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    _load();
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => _load();

  Future<void> _load() async {
    final city = _state.city;
    final year = _state.year;
    final type = _state.type;
    final db = AppDatabase.instance;

    final hasDataset = await db.hasDataset(city, year);
    final points =
        hasDataset ? await db.getPoints(city, year, type: type) : <ChangePoint>[];
    final types = hasDataset ? await db.getTypes(city, year) : <String>[];
    final tracked = await db.getTrackedUids();

    if (!mounted) return;
    final key = '$city|$year|$type';
    final datasetChanged = key != _loadedKey;
    setState(() {
      _points = points;
      _illegalUids =
          points.where((p) => p.isIllegal).map((p) => p.uid).toSet();
      _types = types;
      _trackedUids = tracked;
      _hasDataset = hasDataset;
      _loading = false;
      _loadedKey = key;
    });
    if (datasetChanged && points.isNotEmpty) _fitBounds();
  }

  void _fitBounds() {
    if (!_mapReady || _points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(
        _points.map((p) => LatLng(p.lat, p.lng)).toList());
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  Marker _buildMarker(ChangePoint p) {
    final color =
        p.isIllegal ? AppConstants.illegalColor : AppConstants.legalColor;
    final tracked = _trackedUids.contains(p.uid);
    return Marker(
      key: ValueKey(p.uid),
      point: LatLng(p.lat, p.lng),
      width: 36,
      height: 36,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => showPointSheet(context, p),
        child: Stack(
          children: [
            Icon(Icons.location_on,
                color: color,
                size: 36,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 4)]),
            if (tracked)
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(Icons.star, color: Colors.amber, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _points.map(_buildMarker).toList();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(23.000694, 120.221507),
              initialZoom: 11,
              maxZoom: 19,
              onMapReady: () {
                _mapReady = true;
                _fitBounds();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _usePhotoLayer
                    ? AppConstants.nlscPhotoUrl
                    : AppConstants.nlscEmapUrl,
                userAgentPackageName: 'tw.olc.landchg_tracker',
                maxZoom: 19,
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(42, 42),
                  markers: markers,
                  spiderfyCircleRadius: 60,
                  zoomToBoundsOnClick: true,
                  showPolygon: false,
                  builder: (context, clusterMarkers) {
                    final hasIllegal = clusterMarkers.any((m) {
                      final key = m.key;
                      return key is ValueKey<String> &&
                          _illegalUids.contains(key.value);
                    });
                    return Container(
                      decoration: BoxDecoration(
                        color: hasIllegal
                            ? AppConstants.illegalColor
                            : AppConstants.legalColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${clusterMarkers.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    );
                  },
                ),
              ),
              const SimpleAttributionWidget(
                source: Text(AppConstants.nlscAttribution,
                    style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          // Filter bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DatasetFilterBar(types: _types),
                  const SizedBox(height: 6),
                  _buildLegend(),
                ],
              ),
            ),
          ),
          if (!_loading && !_hasDataset) _buildDownloadPrompt(),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'layer',
            tooltip: _usePhotoLayer ? '切換電子地圖' : '切換正射影像',
            onPressed: () => setState(() => _usePhotoLayer = !_usePhotoLayer),
            child: Icon(_usePhotoLayer ? Icons.map : Icons.satellite_alt),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'fit',
            tooltip: '顯示全部點位',
            onPressed: _fitBounds,
            child: const Icon(Icons.zoom_out_map),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: color, size: 16),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(AppConstants.illegalColor, '違規'),
            const SizedBox(width: 10),
            item(AppConstants.legalColor, '非違規/其他'),
            const SizedBox(width: 10),
            Text('共 ${_points.length} 點',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadPrompt() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_download, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('尚未下載 ${_state.city} ${_state.year}年 資料',
                  style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('立即下載'),
                onPressed: () => downloadDatasetWithProgress(
                    context, _state.city, _state.year),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
