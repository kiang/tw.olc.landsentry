# 建置與發佈指南 (Build & Publish Guide)

LandSentry 國土巡守隊 — Flutter Android app。

## 環境需求

| 工具 | 版本 |
|------|------|
| Flutter | 3.41+（stable channel） |
| Android SDK | API 36（compileSdk 跟隨 Flutter 預設） |
| JDK | 17 |
| minSdk | 24（Android 7.0+） |

確認環境：

```bash
flutter doctor
```

## 取得依賴與開發執行

```bash
flutter pub get
flutter run -d <device-id>        # flutter devices 查詢裝置
```

模擬器空間不足裝不下 debug APK（約 150MB）時，可改用單一架構的
release 建置（約 20MB）：

```bash
flutter build apk --release --target-platform android-x64   # 模擬器用
adb -s <emulator-id> install -r build/app/outputs/flutter-apk/app-release.apk
```

## 建置 Release APK（側載 / 直接散佈）

```bash
flutter build apk --release
# 輸出：build/app/outputs/flutter-apk/app-release.apk（通用，含 arm64/arm/x64）
```

縮小檔案可改為依架構分拆：

```bash
flutter build apk --release --split-per-abi
# 輸出 app-arm64-v8a-release.apk 等，一般手機裝 arm64-v8a 即可
```

安裝到實體裝置：

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 正式簽章（發佈前必做）

目前 `android/app/build.gradle.kts` 的 release 仍使用 debug 簽章
（檔內有 TODO 註記），上架前需建立正式 keystore：

```bash
keytool -genkey -v -keystore ~/landsentry-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias landsentry
```

建立 `android/key.properties`（**勿提交版本控制**，已在 .gitignore 建議加入）：

```properties
storePassword=<密碼>
keyPassword=<密碼>
keyAlias=landsentry
storeFile=/home/<user>/landsentry-release.jks
```

修改 `android/app/build.gradle.kts`：

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

**注意**：換成正式簽章後，先前以 debug 簽章安裝的版本必須移除才能更新安裝。

## 發佈到 Google Play

1. 調整版本號：`pubspec.yaml` 的 `version: 1.0.0+1`
   （`+` 後為 versionCode，每次上傳必須遞增）。
2. 建置 App Bundle：

   ```bash
   flutter build appbundle --release
   # 輸出：build/app/outputs/bundle/release/app-release.aab
   ```

3. 在 [Play Console](https://play.google.com/console) 建立應用程式
   （套件名稱 `tw.olc.landsentry`），上傳 `.aab`。
4. 填寫商店資訊與審查必要項目，與本 app 相關的重點：
   - **權限聲明**：定位（`ACCESS_FINE_LOCATION`，用於地圖定位與距離計算）。
     相機/相簿經由系統 photo picker，不需額外權限聲明。
   - **資料安全表單**：所有追蹤資料與照片僅儲存在裝置本機 SQLite 與
     app 私有目錄；分享為使用者主動匯出，app 不上傳任何資料到伺服器。
   - 隱私權政策網址（Play 要求有定位權限的 app 必須提供）。

## 測試與檢查

```bash
flutter analyze          # 靜態分析
flutter test             # 單元 / widget 測試（含匯入合併邏輯測試）
```

## App 圖示更新

圖示來源檔在 `assets/icon/`（icon.png、icon_fg.png、icon_bg.png、
icon_mono.png，皆 1024×1024）。替換後重新產生各解析度：

```bash
dart run flutter_launcher_icons
```

## 資料來源

變異點 CSV 由 https://kiang.github.io/landchg.tcd.gov.tw/ 提供
（源自內政部國土利用監測整合資訊網），路徑格式：

```
https://kiang.github.io/landchg.tcd.gov.tw/csv/points/{民國年}/{縣市}.csv
```

地圖底圖為國土測繪圖資服務雲 (NLSC) WMTS：電子地圖 `EMAP`、正射影像 `PHOTO2`。
