import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../constants.dart';
import '../db/database.dart';
import '../models/point.dart';
import '../widgets/dataset_picker.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final AppState _state = AppState.instance;
  List<Dataset> _datasets = [];
  String _city = AppConstants.defaultCity;
  int _year = AppConstants.currentRocYear;

  @override
  void initState() {
    super.initState();
    _city = _state.city;
    _year = _state.year;
    _state.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _state.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final datasets = await AppDatabase.instance.getDatasets();
    if (!mounted) return;
    setState(() => _datasets = datasets);
  }

  Future<void> _download(String city, int year) async {
    await downloadDatasetWithProgress(context, city, year);
    await _load();
  }

  Future<void> _delete(Dataset d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除資料'),
        content: Text('確定要刪除 ${d.city} ${d.year}年 的資料嗎？\n追蹤中的點位與紀錄會保留。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('刪除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppDatabase.instance.deleteDataset(d.city, d.year);
    AppState.instance.notifyDataChanged();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy/MM/dd HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('資料管理')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('下載資料集',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _city,
                          decoration: const InputDecoration(
                              labelText: '縣市',
                              border: OutlineInputBorder(),
                              isDense: true),
                          items: AppConstants.cities
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (c) =>
                              setState(() => _city = c ?? _city),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _year,
                          decoration: const InputDecoration(
                              labelText: '年份(民國)',
                              border: OutlineInputBorder(),
                              isDense: true),
                          items: AppConstants.years
                              .map((y) => DropdownMenuItem(
                                  value: y, child: Text('$y年')))
                              .toList(),
                          onChanged: (y) =>
                              setState(() => _year = y ?? _year),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('下載'),
                      onPressed: () => _download(_city, _year),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('已下載資料集 (${_datasets.length})',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (_datasets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('尚未下載任何資料',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          ..._datasets.map((d) => Card(
                child: ListTile(
                  leading: const Icon(Icons.dataset),
                  title: Text('${d.city} ${d.year}年'),
                  subtitle: Text(
                      '${d.count} 筆・更新於 ${df.format(d.fetchedAt)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: '重新下載',
                        onPressed: () => _download(d.city, d.year),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '刪除',
                        onPressed: () => _delete(d),
                      ),
                    ],
                  ),
                  onTap: () => _state.setDataset(d.city, d.year),
                ),
              )),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('關於資料',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    '資料來源：內政部國土利用監測整合資訊網（landchg.tcd.gov.tw），'
                    '經 kiang.github.io 整理為開放格式。'
                    '變異點為衛星影像判釋出的土地利用變化，紅色標記代表查證為違規的案件。',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
