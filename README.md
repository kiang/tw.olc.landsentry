# LandSentry 國土巡守隊 (landsentry)

Flutter Android app for downloading 國土利用監測 (land-use change detection)
points and locally logging / tracking the status of each point. Companion to
the web map at https://tainan.olc.tw/p/landchg/.

## Data source

CSV per city/year (ROC era) from
`https://kiang.github.io/landchg.tcd.gov.tw/csv/points/{year}/{city}.csv`
(originally from 內政部國土利用監測整合資訊網, landchg.tcd.gov.tw).

## Features

- **地圖**: NLSC base layers (電子地圖 EMAP / 正射影像 PHOTO2) with clustered
  markers — red for 違規, blue for others; tap a marker for a quick summary.
- **清單**: searchable/filterable point list (case ID, type, agency, 違規 only).
- **追蹤**: per-point tracking status (追蹤中 / 已改善 / 無變化 / 惡化中 / 已結案)
  with a timestamped log timeline; all stored locally in SQLite. Log entries
  support photo attachments (camera or gallery via the system photo picker);
  photos are stored in app documents and viewable fullscreen with pinch-zoom.
- **資料**: download/update/delete datasets per city + year; deleting a dataset
  keeps tracked points and their history.
- Detail page: orthophoto mini-map, all CSV fields, links to Google/Bing
  satellite and landchg.olc.tw case page.
- GPS: my-location button on the map (blue dot, live updates), distance to
  the point shown in the marker sheet and detail page, and 導航 buttons that
  launch Google Maps turn-by-turn navigation (web directions fallback).
- Sharing: tracking records and logs use UUID primary keys (points keep their
  government-issued ID) so data from different users merges cleanly. 匯出分享
  packs tracking + logs + photos into one zip via the share sheet (e.g. save
  to Google Drive); 匯入合併 picks an archive from any document provider
  (e.g. a Drive folder) and merges it — newer tracking status wins, logs
  union by UUID, photos copied if missing.

## Documentation

- [建置與發佈指南](docs/build.md) — environment, release builds, signing,
  Play Store publishing, icon regeneration
- [使用指南](docs/usage.md) — per-feature usage guide (map, list, tracking,
  photo logs, GPS/navigation, Drive export/import)

## Build

```
flutter pub get
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

## Structure

- `lib/constants.dart` — data URL, city list, NLSC tile URLs
- `lib/db/database.dart` — SQLite schema (points, datasets, tracking, logs)
- `lib/services/api.dart` — CSV download + parse
- `lib/screens/` — map / list / tracked / detail / download screens
- `lib/widgets/` — shared filter bar, point bottom sheet
