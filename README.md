# Sthira

Welcome to the Sthira project repository. This codebase provides a clean, private, local-first functional tracking interface. 

## Requirements
- Flutter SDK (`^3.12.2`)

## Repository Initialization
Upon first clone, execute the following to retrieve the verified functional baseline:
```bash
flutter pub get
```

## Running Local Tests
A functional Isar test database core is required for testing. 
On Windows, you must download the pre-compiled `isar.dll`:
```bash
dart run download_isar.dart
```
Following this, you can execute all tests via:
```bash
flutter test
```

## Disclaimer
Sthira utilizes `health` and `screentime` permission tracking on native targets. For iOS execution or distribution, ensure the respective usage strings are properly mapped in your `Info.plist`.
