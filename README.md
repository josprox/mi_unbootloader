# Mi Bootloader Unlocker

A Flutter application designed to unlock the bootloader of Xiaomi devices.

![App Logo](assets/default.png)

## Features

-   **Material 3 Design:** Supports dynamic colors based on the user's wallpaper (Android 12+).
-   **Bootloader Unlocking:** Automates the unlocking process.
-   **Background Service:** Handles long-running tasks.
-   **Time Synchronization:** Uses NTP for precise timing.

## Getting Started

### Prerequisites

-   Flutter SDK
-   Android Studio / VS Code
-   Java 17 (required for the build)
-   Xiaomi Account with unlock permissions

### Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/yourusername/mi_unbootloader.git
    cd mi_unbootloader
    ```

2.  Install dependencies:
    ```bash
    flutter pub get
    ```

3.  Set up signing keys:
    -   Copy `android/key.properties.example` to `android/key.properties`.
    -   Update `android/key.properties` with your keystore path and passwords.
    -   **Note:** The keystore file is NOT included in the repository for security reasons.

4.  Run the app:
    ```bash
    flutter run
    ```

## Building for Release

To build a release APK/Bundle:

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

Ensure `android/key.properties` is correctly configured before building.

## Architecture

This project uses the provided Flutter architecture with:
-   `lib/services`: Background tasks, Notifications, DB.
-   `lib/ui`: User Interface screens.
-   `lib/core`: Constants and core logic.

## Credits

Developed by Joss Estrada.
