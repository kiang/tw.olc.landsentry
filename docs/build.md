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

## 步驟一：建立簽章金鑰（發佈前必做，一次性）

目前 `android/app/build.gradle.kts` 的 release 仍使用 debug 簽章
（檔內有 TODO 註記），上架前必須改用正式金鑰。

### 1. 產生 upload keystore

```bash
keytool -genkey -v -keystore ~/landsentry-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

依提示輸入密碼與識別資訊（姓名/組織/城市等）。

**金鑰保管**：
- keystore 檔與密碼遺失將無法再更新 app（除非已啟用 Play App Signing，
  見步驟三），請備份到安全位置（密碼管理器 + 離線備份）。
- 絕對不要把 keystore 或密碼提交進版本控制
  （`android/.gitignore` 已排除 `key.properties`、`*.keystore`、`*.jks`）。

### 2. 建立 `android/key.properties`

```properties
storePassword=<keystore 密碼>
keyPassword=<key 密碼>
keyAlias=upload
storeFile=/home/<user>/landsentry-upload.jks
```

### 3. 修改 `android/app/build.gradle.kts`

檔案開頭（`plugins` 區塊之前）加入：

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
```

`android { }` 內加入 signingConfigs，並把 release buildType 改為使用它
（取代現有的 `signingConfig = signingConfigs.getByName("debug")`）：

```kotlin
android {
    // ...既有設定...

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

### 4. 驗證簽章

```bash
flutter build apk --release
~/Android/Sdk/build-tools/36.0.0/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

輸出的憑證資訊應對應你在 keytool 輸入的識別資訊（而非 Android Debug）。

**注意**：換成正式簽章後，先前以 debug 簽章安裝的版本必須先解除安裝
（`adb uninstall tw.olc.landsentry`）才能安裝新簽章版本。

## 步驟二：建置上架用 App Bundle

1. 每次上傳前調整 `pubspec.yaml` 版本號：

   ```yaml
   version: 1.0.0+1   # 格式：versionName+versionCode
   ```

   `+` 後的 versionCode 每次上傳 **必須遞增**；前面的 versionName
   是使用者看到的版本。

2. 建置：

   ```bash
   flutter build appbundle --release
   # 輸出：build/app/outputs/bundle/release/app-release.aab
   ```

3. 上傳前先用 APK 在實機做最後測試（aab 不能直接安裝）：

   ```bash
   flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

## 步驟三：Play Console 上架流程

### 建立開發者帳號與應用程式

1. 註冊 [Google Play Console](https://play.google.com/console) 開發者帳號
   （一次性費用 US$25）。
2. 「建立應用程式」：
   - 應用程式名稱：**國土巡守隊**
   - 預設語言：繁體中文 (zh-TW)
   - 類型：應用程式；價格：免費
3. 第一次上傳 `.aab` 時套件名稱會自動鎖定為 `tw.olc.landsentry`，
   之後無法更改。

### 啟用 Play App Signing（建議）

首次上傳 aab 時 Play 會引導加入 **Play App Signing**：Google 保管
正式簽署金鑰，你手上的 keystore 作為 upload key。好處是 upload key
遺失時可向 Google 申請重設，不會永久失去更新能力。依預設流程
「使用 Google 產生的金鑰」即可。

### 填寫應用程式內容（App content）

審查必填項目，依本 app 的實際情況：

| 項目 | 填寫內容 |
|------|----------|
| 隱私權政策 | 必填（app 要求定位權限）。提供一個說明資料僅存於裝置本機的網頁網址 |
| 廣告 | 無廣告 |
| 應用程式存取權 | 所有功能皆可直接使用，無需登入（選「無特殊存取需求」） |
| 內容分級 | 填問卷；本 app 無使用者產生之公開內容、無暴力等，通常為 3+ |
| 目標對象 | 18 歲以上（或 13+；非兒童導向） |
| 資料安全 | 見下方 |
| 政府 app | 否（民間開放資料應用） |

**資料安全表單**重點：追蹤紀錄、照片、定位皆只在裝置端處理與儲存，
app 沒有後端伺服器、不傳輸任何使用者資料 → 可宣告
「不收集、不分享任何使用者資料」。匯出 zip 為使用者主動操作，
不屬於 app 的資料收集。

### 商店資訊（Store listing)

- 簡短說明（80 字內）與完整說明：可參考 README 的功能介紹。
- 圖示：512×512（可由 `assets/icon/icon.png` 縮製）。
- 主題圖片 (feature graphic)：1024×500。
- 截圖：手機截圖至少 2 張（地圖、追蹤頁建議入鏡）。

### 發佈

1. 建議先走 **內部測試**（Internal testing）：上傳 aab、加入測試者
   email，確認安裝與更新流程正常。
2. 沒問題後在 **正式版**（Production）建立版本：上傳同一個 aab、
   填寫版本資訊（release notes），送出審查。
3. 首次審查通常需數天；通過後即上架。

### 後續更新

```bash
# 1. pubspec.yaml versionCode +1（例如 1.0.1+2）
# 2. 重新建置並上傳
flutter build appbundle --release
```

到 Play Console 的正式版建立新版本、上傳 aab、填寫更新說明、送審。

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
