# Kosguard for Android

Kosguard is a Flutter mobile application for boarding house (_kos_) residents and owners to register belongings kept in shared spaces (**Kulkas** and **Jemuran**), verify ownership via Room QR codes, browse shared inventory, and manage incident reports and ownership claims.

## Offline Demo Accounts (No Server Required)

The app includes a built-in offline demo mode[cite: 3]. Log in using either account below with **any password** (minimum 6 characters, e.g., `123456`)[cite: 3]:

| Role                      | Email                      | Password             | Demo Profile                              |
| :------------------------ | :------------------------- | :------------------- | :---------------------------------------- |
| **Resident (_Penghuni_)** | `juri@kosguard.test`       | Any (e.g., `123456`) | Juri Demo (Penghuni) · Room A-04[cite: 3] |
| **Owner (_Pemilik Kos_)** | `owner.juri@kosguard.test` | Any (e.g., `123456`) | Pemilik Kos (Demo Offline)[cite: 3]       |

## Key Features

- **Shared Space Inventory:** Register, track, and retrieve personal items stored in shared refrigerators (_Kulkas_) and drying racks (_Jemuran_)[cite: 3].
- **Room QR Identity:** Generate and scan room QR tokens to inspect room-linked items without exposing private resident contact details[cite: 3].
- **Incident Reporting & Claims:** Report missing (`MISSING`) or found (`FOUND`) belongings, submit private ownership claims, and review claims from the owner dashboard[cite: 3].

## Run on Android

1. Install Flutter and Android Studio, then connect an Android device with USB debugging enabled or start an emulator.
2. From this project folder, run:

   ```powershell
   flutter pub get
   flutter run -d <android-device-id>
   ```

   Use `flutter devices` to find the connected device ID.

## Build APK

- **Release APK:**

  ```powershell
  flutter build apk --release
  ```

  Output: `build/app/outputs/flutter-apk/app-release.apk`

- **Debug APK:**
  ```powershell
  flutter build apk --debug
  ```
  Output: `build/app/outputs/flutter-apk/app-debug.apk`
