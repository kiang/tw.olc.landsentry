import 'package:flutter/material.dart';

import '../app_state.dart';
import '../constants.dart';
import '../db/database.dart';
import '../models/point.dart';
import '../models/tracking.dart';
import '../screens/detail_screen.dart';

/// Quick summary bottom sheet shown when a marker is tapped.
Future<void> showPointSheet(BuildContext context, ChangePoint p) async {
  final tracking = await AppDatabase.instance.getTracking(p.uid);
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final color =
          p.isIllegal ? AppConstants.illegalColor : AppConstants.legalColor;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.type,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Chip(
                  label: Text(
                    p.verification.isEmpty ? '未知' : p.verification,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: color,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('編號：${p.caseId}'),
            if ((p.props['權責單位'] ?? '').isNotEmpty)
              Text('權責單位：${p.props['權責單位']}'),
            Text('${p.city} ${p.year}年'),
            if (tracking != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(tracking.status.icon,
                        color: tracking.status.color, size: 18),
                    const SizedBox(width: 4),
                    Text('追蹤狀態：${tracking.status.label}',
                        style: TextStyle(color: tracking.status.color)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.info_outline),
                    label: const Text('詳細與紀錄'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => DetailScreen(uid: p.uid)),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (tracking == null)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.star_border),
                      label: const Text('加入追蹤'),
                      onPressed: () async {
                        final db = AppDatabase.instance;
                        await db.setTracking(p.uid, TrackStatus.watching);
                        await db.addLog(LogEntry(
                          pointUid: p.uid,
                          status: TrackStatus.watching,
                          note: '開始追蹤',
                          createdAt: DateTime.now(),
                        ));
                        AppState.instance.notifyDataChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
