import 'package:flutter/material.dart';

import '../app_state.dart';
import '../constants.dart';
import '../models/point.dart';
import '../services/api.dart';

/// City / year / type filter bar shared by the map and list screens.
class DatasetFilterBar extends StatelessWidget {
  final List<String> types;
  const DatasetFilterBar({super.key, this.types = const []});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              DropdownButton<String>(
                value: state.city,
                underline: const SizedBox.shrink(),
                items: AppConstants.cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (c) {
                  if (c != null) state.setDataset(c, state.year);
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: state.year,
                underline: const SizedBox.shrink(),
                items: AppConstants.years
                    .map((y) =>
                        DropdownMenuItem(value: y, child: Text('$y年')))
                    .toList(),
                onChanged: (y) {
                  if (y != null) state.setDataset(state.city, y);
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: types.contains(state.type) || state.type == 'all'
                    ? state.type
                    : 'all',
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('全部類型')),
                  ...types.map(
                      (t) => DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: (t) {
                  if (t != null) state.setType(t);
                },
              ),
              const SizedBox(width: 12),
              DropdownButton<VerificationFilter>(
                value: state.verification,
                underline: const SizedBox.shrink(),
                items: VerificationFilter.values
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          v.label,
                          style: v == VerificationFilter.illegal
                              ? TextStyle(
                                  color: AppConstants.illegalColor,
                                  fontWeight: FontWeight.bold)
                              : null,
                        )))
                    .toList(),
                onChanged: (v) {
                  if (v != null) state.setVerification(v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Downloads a dataset showing a progress dialog; notifies app state on
/// completion so all screens refresh.
Future<void> downloadDatasetWithProgress(
    BuildContext context, String city, int year) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text('下載 $city $year年 資料中...')),
        ],
      ),
    ),
  );

  String message;
  try {
    final count = await ApiService.downloadDataset(city, year);
    message = count > 0 ? '已下載 $count 筆變異點' : '此縣市年份無資料';
  } catch (e) {
    message = '下載失敗，請檢查網路連線';
  }

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
  AppState.instance.notifyDataChanged();
}
