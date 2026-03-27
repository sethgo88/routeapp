# Android Development Setup — Windows 11

One-time prerequisites shared across all three routeapp implementations.

## 1. Android Studio

Download and install from https://developer.android.com/studio (latest stable).

After installation, open Android Studio and complete the setup wizard (installs Android SDK, emulator, etc.).

**Recommended SDK components** (SDK Manager → SDK Tools tab):
- Android SDK Build-Tools (latest)
- Android SDK Platform-Tools
- Android SDK Platform (API 35 — Android 15)
- Android Emulator
- NDK (Side by side) — required for Tauri and Flutter builds

Note the **Android SDK Location** from the SDK Manager (typically `C:\Users\<you>\AppData\Local\Android\Sdk`). You'll need this path.

## 2. Environment Variables

Set these in Windows System Properties → Environment Variables:

```
ANDROID_HOME = C:\Users\<you>\AppData\Local\Android\Sdk
ANDROID_SDK_ROOT = C:\Users\<you>\AppData\Local\Android\Sdk  (some tools use this alias)
```

Add to PATH:
```
%ANDROID_HOME%\platform-tools
%ANDROID_HOME%\emulator
```

**Reboot Windows after setting environment variables.** Many build tools cache env vars at startup.

## 3. Physical Device Setup (Recommended over emulator)

MapLibre WebGL and native rendering perform best on a real device.

1. On your Android phone: Settings → About Phone → tap "Build Number" 7 times to enable Developer Options
2. Settings → Developer Options → enable "USB Debugging"
3. Connect phone via USB; accept the "Allow USB Debugging" prompt on the phone
4. Verify: `adb devices` should list your device

## 4. Java / JDK

Android Studio bundles a JDK — no separate install needed. If you need it outside Android Studio:
```
%ANDROID_HOME%\..\Android Studio\jbr\bin
```

## 5. Flutter-Specific Setup

See `docs/framework-notes/flutter.md` for Flutter SDK installation.

## 6. Tauri-Specific Setup

See `docs/framework-notes/tauri.md` for Rust + NDK configuration.

## 7. Kotlin-Specific Setup

Kotlin/Compose only needs Android Studio — no additional tooling.

## Verifying Setup

**ADB working:**
```bash
adb devices   # should show your device or emulator
```

**Flutter:**
```bash
flutter doctor  # diagnoses all Flutter + Android dependencies
```

**Tauri:**
```bash
pnpm tauri android init  # will fail loudly if NDK_HOME or env vars missing
```

**Kotlin:**
Build from Android Studio — it will report missing SDK components in the sync output.
