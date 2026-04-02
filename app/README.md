# FitnessAI Mobile App

Flutter mobile app for iOS and Android.

## Requirements

- Flutter 3.32+ / Dart 3.8+
- Backend services running (Docker Compose)

## Setup

```bash
cd app
flutter pub get
flutter run
```

## Architecture

Clean Architecture with feature-based structure:

```
lib/
  core/           # Shared: theme, widgets, network, storage, router
  features/
    auth/         # Authentication (login, register, JWT)
    workout/      # Workout tracking (plans, sessions, sets)
    history/      # Workout history
    stats/        # Statistics and charts
    profile/      # User profile and settings
    ai/           # AI Vision and Coach
```

## Stack

- **State**: Riverpod 3.x with Notifier
- **Navigation**: go_router
- **Network**: Dio with JWT auth interceptor
- **Storage**: Hive (offline-first) + flutter_secure_storage (JWT)
- **Design**: Dark mode premium (from GymTracker prototype)

## Tests

```bash
flutter test
flutter analyze
```
