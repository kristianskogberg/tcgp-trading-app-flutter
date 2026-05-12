# tcgp_trading_app

A new Flutter project.

## Android setup

Create a local `.env` file from `.env.example` before running or building the
app. The app now fails fast on startup if any required `.env` value is empty.

Firebase files are intentionally local-only because they identify your Firebase
project. Generate them with FlutterFire instead of committing them:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project <your-firebase-project-id>
```

After configuration, Android builds require `android/app/google-services.json`
and Flutter imports `lib/firebase_options.dart`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
