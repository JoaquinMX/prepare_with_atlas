# Spec 01: App Foundation — tasks.md

## Phase 1: Project Scaffolding

- **T001**: Create Flutter project with `flutter create --platforms=macos --org com.joaquinmx prepare_with_atlas`. Verify it builds and runs on macOS.
- **T002**: Verify bundle identifier `com.joaquinmx.preparewithatlas` is set in `macos/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`) and `macos/Runner/Info.plist`. Update if needed.
- **T003**: Add all dependencies to `pubspec.yaml`: `flutter_riverpod`, `go_router`, `drift`, `sqlite3_flutter_libs`, `path_provider`, `freezed`, `freezed_annotation`, `json_annotation`, `build_runner`, `drift_dev`, `json_serializable`, `google_fonts`, `flutter_test`, `very_good_analysis` (dev).
- **T004**: Configure `analysis_options.yaml` to use `package:very_good_analysis/analysis_options.yaml`. Enable all rules. Run `flutter analyze` — verify zero warnings.
- **T005**: Configure macOS entitlements — add `com.apple.security.network.client` to both `DebugProfile.entitlements` and `Release.entitlements`.
- **T006**: Set up project folder structure matching the feature-first architecture (create all directories under `lib/features/`, `lib/app/`, `lib/shared/`).
- **T007**: Add pre-commit script or CI check that runs `flutter analyze && flutter test` — fails build if either fails.

## Phase 2: Theme System (TDD)

- **T008**: Write tests for `AtlasColors` — verify light and dark color values exist and are distinct for each semantic token.
- **T009**: Implement `AtlasColors` class with light/dark color tokens (accent, background, surface, onSurface, border, success, warning, danger).
- **T010**: Write tests for `AtlasTypography` — verify text theme returns correct font family (Inter), sizes, and weights for each style.
- **T011**: Implement `AtlasTypography` with `textTheme()` method returning full TextTheme using GoogleFonts.inter, plus `timerDisplay()` using JetBrains Mono.
- **T012**: Write tests for `AtlasSpacing` — verify spacing constants and EdgeInsets values.
- **T013**: Implement `AtlasSpacing` class with spacing scale (4, 8, 16, 24, 32, 48, 64) and component constants.
- **T014**: Write tests for `AtlasTheme` — verify `ThemeData.light()` and `ThemeData.dark()` use correct color schemes and typography.
- **T015**: Implement `AtlasTheme` class that composes `AtlasColors`, `AtlasTypography`, and `AtlasSpacing` into `ThemeData` for light and dark modes.

## Phase 3: Database (TDD)

- **T016**: Write Drift table definitions for all 7 tables: `Problems`, `InterviewSessions`, `StageNotes`, `WhiteboardSnapshots`, `Evaluations`, `AiProviderConfigs`, `AppSettings`.
- **T017**: Define `AppDatabase` class extending `_$AppDatabase` with all tables, run code generation (`dart run build_runner build`).
- **T018**: Write integration tests for database — verify: database creates successfully, all tables exist, CRUD operations work on `AppSettings` table, cascade deletes work (deleting session deletes its stage notes and snapshots).
- **T019**: Implement `SettingsRepository` abstract port in `features/settings/domain/`.
- **T020**: Write tests for `DriftSettingsRepository` — verify: read returns defaults when empty, write persists theme mode, update overwrites existing settings.
- **T021**: Implement `DriftSettingsRepository` in `features/settings/data/`.

## Phase 4: Navigation and Routing (TDD)

- **T022**: Define route path constants in `app/routes.dart`.
- **T023**: Write tests for router configuration — verify: all defined routes resolve to correct screens, unknown routes redirect to home.
- **T024**: Implement `GoRouter` configuration in `app/router.dart` with placeholder screens for all routes.

## Phase 5: App Shell and Providers

- **T025**: Create `shared/providers.dart` with top-level Riverpod providers: `appDatabaseProvider`, `settingsControllerProvider`.
- **T026**: Write tests for `SettingsController` — verify: initializes with default theme, toggleTheme() cycles through system/light/dark, persists changes via repository.
- **T027**: Implement `SettingsController` (StateNotifier) in `features/settings/application/`.
- **T028**: Build `AtlasApp` widget (`MaterialApp.router`) that reads theme from `SettingsController` and applies it.
- **T029**: Write widget tests for `HomeScreen` — verify: navigation sidebar renders, clicking nav items navigates to correct routes, theme toggle button works.
- **T030**: Build `HomeScreen` with navigation sidebar and placeholder content areas for "Recent Sessions" and "Quick Start."
- **T031**: Implement `main.dart` with `ProviderScope`, database initialization, and `AtlasApp`.
