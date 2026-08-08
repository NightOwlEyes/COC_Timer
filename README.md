<p align="center">
  <a href="README.md">English</a> | <a href="README-vi.md">Tiếng Việt</a>
</p>

<p align="center">
  <img src="Screenshot/logo.png" alt="COC Timer Logo" width="300"/>
</p>

## 📥 Download

| ABI | Compatible with | Download |
|------|-------------|-----------|
| **arm64-v8a** | ⭐ Recommended (compatible with most Android devices from around 2018 to present) | [![Download](https://img.shields.io/badge/Download-APK-34A853?style=for-the-badge&logo=android&logoColor=white)](https://github.com/NightOwlEyes/COC_Timer/releases/download/v1.0.0-beta.5/app-arm64-v8a-release.apk) |
| **armeabi-v7a** | 32-bit Android devices using ARM CPUs (approximately before 2017–2018) | [![Download](https://img.shields.io/badge/Download-APK-4285F4?style=for-the-badge&logo=android&logoColor=white)](https://github.com/NightOwlEyes/COC_Timer/releases/download/v1.0.0-beta.5/app-armeabi-v7a-release.apk) |
| **x86_64** | The device uses a 64-bit Android emulator with an Intel/AMD x86 CPU. | [![Download](https://img.shields.io/badge/Download-APK-FBBC05?style=for-the-badge&logo=android&logoColor=black)](https://github.com/NightOwlEyes/COC_Timer/releases/download/v1.0.0-beta.5/app-x86_64-release.apk) |

# COC Timer

An app for tracking upgrade timers for buildings, spells, troops, pets, and more in Clash of Clans, with a built-in reminder/alarm system for when they finish.

## Features

The app supports **3 reminder modes** for each item:

| Mode | Description |
|---|---|
| 🔕 No notification | No reminder when the upgrade finishes |
| 🔔 Notification reminder | Send a notification when completed |
| ⏰ Alarm | Sound an alarm when finished |

## How to use

1. In the game, go to **Settings** > **More Settings** > **Export village data as JSON**
2. Open the COC Timer app
3. Scroll down and tap **Paste** to import the JSON data you just exported
4. Tap the **name of any item** to cycle through the 3 reminder modes
5. Tap the **group title** (e.g. Builders, Pets, Laboratory) to change the mode for the **whole group** at once

### Date of completion

The app has a toggle for how time is displayed:
- **Off**: shows a countdown (e.g. `2h 15m`)
- **On**: shows the actual completion time (e.g. `14:30`)

## Screenshots
<p align="center">
  <img src="Screenshot/icon.png" alt="COC Timer Icon" width="120"/>
</p>
<p align="center">
  <img src="Screenshot/1en.png" width="250"/>
  <img src="Screenshot/2en.png" width="250"/>
</p>

---

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
