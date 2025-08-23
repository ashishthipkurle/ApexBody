
# ApexBody

ApexBody is a cross-platform fitness helper app built with Flutter. It helps gym-goers and trainers manage workout sessions, track progress, and access personalized plans. The project is focused on a simple, responsive UI and secure user authentication.

Who it's for
- Gym members who want to track workouts and progress.
- Personal trainers who need to manage clients and export basic reports.

What the app does (high level)
- User authentication (Supabase)
- Deep-link based flows (password reset / recovery)
- Basic dashboard and workout screens
- Admin exports (CSV) and local persistence with Hive

How it was made
- Frontend: Flutter (Dart) supporting Android, iOS, web, and desktop targets.
- Backend integrations: Supabase for authentication and data storage.
- Local storage: Hive for small export/history persistence.
- Deep linking: `app_links` package for custom-scheme links.
- Assets: launcher and UI images stored in `assets/` (logo: `assets/ApexBody_logo.png`).

Quick local setup
1. Install Flutter and ensure it's on your PATH.
2. From the project root run these commands in PowerShell:

```powershell
flutter pub get
flutter pub run flutter_launcher_icons:main
flutter run -d <device-id>
```

Notes for iOS
- Open `ios/Runner.xcworkspace` in Xcode to set your signing team and provisioning before building to a device or uploading to App Store Connect.

Notes about icons
- The repo includes `assets/ApexBody_logo.png`. The `flutter_launcher_icons` config in `pubspec.yaml` will generate platform icons from that file when you run the command above.

Contributing
- Make small, focused branches and open pull requests. Run the app locally and add tests where appropriate.

License
- This repository does not include a license file. Add one if you plan to publish the code publicly.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
