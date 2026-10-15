# Project Developer Guide & Standards

> **Usage:** Place this file in the root directory of any Flutter project. It serves as the standard development contract for architecture, code limits, widget creation rules, testing conventions, security, flavors, and CI/CD quality gates.

## 1. Project Overview

* **Project Name:** `Ludo Offline`
* **Flutter Version:** `>= 3.19.0`
* **Dart Version:** `>= 3.3.0`
* **Architecture:** Clean Architecture + Feature-First
* **State Management:** BLoC (`flutter_bloc`)
* **Dependency Injection:** `get_it` (service locator registered in `bootstrap.dart`)
* **Networking:** Offline-First (zero network dependencies)
* **Functional Error Handling:** `fpdart` (`Either<Failure, Success>`)

---

## 2. Code Limits & Class Design Standards

Adhere strictly to the following metrics:

### 2.1. Hard Line Limits

| Artifact | Target Length | Hard Limit | Action When Exceeded |
| :--- | :--- | :--- | :--- |
| **Line Width** | $\le 80$ characters | 120 characters | Auto-format using trailing commas |
| **Single Method / Function** | $\le 25$ lines | 40 lines | Extract helper algorithms or use cases |
| **Widget `build()` Method** | $\le 40$ lines | 60 lines | Extract into dedicated child widget classes |
| **Single Class (Total)** | $\le 120$ lines | 200 lines | Break into multiple single-responsibility classes |
| **Source File (`.dart`)** | $\le 150$ lines | 250 lines | Split into individual component files |

### 2.2. Strict Anti-Pattern: No Inner Classes & No Widget Helper Methods

* ❌ **NO Helper Methods Returning Widgets:** Never write `Widget _buildProfileHeader() { ... }` inside a screen.
  * **Why:** Helper methods bypass Flutter's element tree diffing, cause redundant full subtree rebuilds on state change, and leak `BuildContext`.
* ❌ **NO Giant Classes or Multiple Public Classes in One File:** One primary class per `.dart` file.
* ✅ **YES to Dedicated Widget Classes:** Every extracted UI component must be its own independent `StatelessWidget` or `StatefulWidget` with a `const` constructor.

```dart
// ❌ WRONG: Helper Method inside Parent Screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAvatar(), // Causes full screen rebuild when child changes!
      ],
    );
  }

  Widget _buildAvatar() { // Violates Clean Flutter Standard
    return const CircleAvatar(radius: 40);
  }
}

// ✅ CORRECT: Dedicated, Reusable Widget Class with const Constructor
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ProfileAvatarWidget(), // Isolated rebuild boundary & const-cached
      ],
    );
  }
}

class ProfileAvatarWidget extends StatelessWidget {
  const ProfileAvatarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(radius: 40);
  }
}
```

---

## 3. Standard Shared / Common Widgets Strategy

Avoid recreating buttons, form inputs, dialogs, or loaders across different features. All reusable UI components must live in `lib/core/widgets/`:

| Common Widget | Directory Location | Purpose |
| :--- | :--- | :--- |
| `AppPrimaryButton` | `lib/core/widgets/buttons/` | Standard elevated action with built-in loading state |
| `AppOutlinedButton` | `lib/core/widgets/buttons/` | Secondary dismissive or outline action |
| `AppTextFormField` | `lib/core/widgets/inputs/` | Form field with consistent borders, padding, and validation styling |
| `AppLoadingIndicator` | `lib/core/widgets/feedback/` | Centered adaptive loading indicator |
| `AppErrorStateWidget` | `lib/core/widgets/feedback/` | Fallback empty/error view with a retry action button |
| `AppResponsiveContainer` | `lib/core/widgets/layout/` | Standard horizontal padding and max content width constraint |

---

## 4. Multi-Environment Flavors & Config

Never hardcode endpoints or API keys. Manage environments through Dart define flags and configuration objects:

```dart
// core/config/env_config.dart
enum Environment { dev, staging, prod }

class EnvConfig {
  final String appTitle;
  final String baseUrl;
  final bool enableLogging;

  const EnvConfig({
    required this.appTitle,
    required this.baseUrl,
    required this.enableLogging,
  });

  static late final EnvConfig current;

  static void initialize(Environment env) {
    switch (env) {
      case Environment.dev:
        current = const EnvConfig(
          appTitle: '[DEV] App',
          baseUrl: 'https://dev.api.domain.com',
          enableLogging: true,
        );
        break;
      case Environment.staging:
        current = const EnvConfig(
          appTitle: '[STAGE] App',
          baseUrl: 'https://staging.api.domain.com',
          enableLogging: true,
        );
        break;
      case Environment.prod:
        current = const EnvConfig(
          appTitle: 'App',
          baseUrl: 'https://api.domain.com',
          enableLogging: false,
        );
        break;
    }
  }
}
```

* **Entrypoints:**
  * `lib/main_dev.dart` ➔ `EnvConfig.initialize(Environment.dev);`
  * `lib/main_staging.dart` ➔ `EnvConfig.initialize(Environment.staging);`
  * `lib/main_prod.dart` ➔ `EnvConfig.initialize(Environment.prod);`

---

## 5. Security & Network Hardening

Production apps must enforce standard defensive practices:

1. **Secure Storage:** Store all auth tokens, user credentials, and sensitive session state in `flutter_secure_storage` (backed by iOS Keychain and Android KeyStore). Never use `shared_preferences` for security tokens.
2. **Network Interceptor Token Refresh:** Handle `401 Unauthorized` responses in a single centralized `QueuedInterceptor` inside `Dio` to prevent race conditions during refresh.
3. **No Sensitive Data in Logs:** Disable HTTP body/header print statements in production builds.
4. **SSL / Certificate Pinning:** Enforce certificate fingerprint verification for banking, healthcare, or sensitive enterprise backends.
5. **No API Keys in Version Control:** Use `--dart-define` or `.env` templates (with the actual `.env` ignored by git).

---

## 6. Directory Standard (`lib/`)

```
lib/
├── app/                  # Application bootstrap, routing, app-wide theme
│   ├── app.dart
│   ├── router/           # GoRouter / AutoRoute definitions
│   └── theme/            # Theme, color schemes, font definitions
├── core/                 # Shared logic across all features
│   ├── config/           # Environment configs (dev, staging, prod)
│   ├── constants/        # API endpoints, string keys, asset paths
│   ├── errors/           # Failures and Exception definitions
│   ├── network/          # HTTP clients, interceptors, network checker
│   ├── storage/          # Local key-value, secure storage, SQLite/Hive wrappers
│   ├── utils/            # Extension methods, formatters, helpers
│   └── widgets/          # Shared common widgets (Buttons, Inputs, Loaders)
│       ├── buttons/
│       ├── inputs/
│       ├── feedback/
│       └── layout/
├── features/             # Feature-first business modules
│   └── [feature_name]/
│       ├── data/         # Data Sources, DTO models, Repository implementations
│       │   ├── datasources/
│       │   ├── models/
│       │   └── repositories/
│       ├── domain/       # Pure Dart entities, use cases, Repository interfaces
│       │   ├── entities/
│       │   ├── repositories/
│       │   └── usecases/
│       └── presentation/ # BLoCs, UI screens, feature widgets
│           ├── bloc/
│           ├── screens/
│           └── widgets/  # Specific sub-widgets for this feature only (< 100 lines each)
├── bootstrap.dart        # Async setup (Firebase, DI registration, error logging)
├── main_dev.dart         # Development entry point
├── main_staging.dart     # Staging entry point
└── main_prod.dart        # Production entry point
```

---

## 7. Performance & Memory Guidelines

* **Const Everywhere:** Every widget with compile-time known properties must use `const` to skip element rebuilding.
* **ListView Performance:**
  * Use `ListView.builder()` or `CustomScrollView` with `SliverList` for collections with indeterminate lengths.
  * Define `itemExtent` or `prototypeItem` whenever list rows have uniform height.
* **Image Caching & Assets:**
  * Always use `cached_network_image` with explicit `memCacheWidth` and `memCacheHeight` limits to avoid memory bloat.
  * Optimize static assets with modern WebP or vector SVG.
* **Isolates for Heavy Parsing:** Use Dart's `compute()` or worker isolates for JSON payloads larger than 50KB to keep the UI thread rendering at 60/120 fps.

---

## 8. Testing Conventions

All tests reside under `test/` mirroring the `lib/` directory structure.

### 8.1. Generic Unit & Use Case Test Blueprint

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';

class MockRepository extends Mock implements SomeRepository {}

void main() {
  late MockRepository mockRepo;
  late SomeUseCase useCase;

  setUp(() {
    mockRepo = MockRepository();
    useCase = SomeUseCase(mockRepo);
  });

  test('should return entity when repository call succeeds', () async {
    when(() => mockRepo.fetchData())
        .thenAnswer((_) async => const Right(SomeEntity()));

    final result = await useCase();

    expect(result, const Right(SomeEntity()));
    verify(() => mockRepo.fetchData()).called(1);
    verifyNoMoreInteractions(mockRepo);
  });
}
```

### 8.2. Generic BLoC Test Blueprint (`bloc_test`)

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fpdart/fpdart.dart';

class MockSomeUseCase extends Mock implements SomeUseCase {}

void main() {
  late MockSomeUseCase mockUseCase;
  late ExampleBloc bloc;

  setUp(() {
    mockUseCase = MockSomeUseCase();
    bloc = ExampleBloc(someUseCase: mockUseCase);
  });

  tearDown(() => bloc.close());

  blocTest<ExampleBloc, ExampleState>(
    'emits [loading, success] when data is loaded successfully',
    build: () {
      when(() => mockUseCase()).thenAnswer((_) async => const Right('Data'));
      return bloc;
    },
    act: (b) => b.add(LoadDataRequested()),
    expect: () => [
      ExampleState(status: StateStatus.loading),
      ExampleState(status: StateStatus.success, data: 'Data'),
    ],
  );
}
```

---

## 9. Development & CI/CD Checklist

### Terminal Commands Quick Reference

| Command | Purpose |
| :--- | :--- |
| `flutter pub get` | Fetch dependencies |
| `dart run build_runner build --delete-conflicting-outputs` | Run code generators (freezed, injectable) |
| `flutter analyze` | Run static analyzer checks |
| `dart format --set-exit-if-changed .` | Verify proper code formatting |
| `flutter test --coverage` | Run all unit & bloc tests with coverage report |
| `flutter build appbundle -t lib/main_prod.dart --flavor prod` | Build Android release bundle |
| `flutter build ipa -t lib/main_prod.dart --flavor prod` | Build iOS release archive |

### Pull Request (PR) Requirements

* [ ] Class length is under 200 lines and methods are under 40 lines.
* [ ] No private helper methods returning widgets (all extracted into standalone widget classes).
* [ ] Reusable UI components leverage `lib/core/widgets/` rather than duplicates.
* [ ] Sensitive tokens are stored in `flutter_secure_storage`.
* [ ] No hardcoded API keys or base URLs (uses `EnvConfig`).
* [ ] Large lists use `ListView.builder` with caching parameters.
* [ ] Zero analyzer errors or linter warnings.
* [ ] Unit and BLoC tests cover new use cases and state transitions.