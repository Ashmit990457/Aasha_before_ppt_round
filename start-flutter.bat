@echo off
cd /d "%~dp0flutter-app"
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
