# Spec 01: App Foundation — spec.md

## Summary

The foundational shell of PrepareWithAtlas — a Flutter macOS desktop application. Provides project scaffolding, theme system (dark/light), navigation routing, and the Drift SQLite database with all tables. This spec delivers no user-facing features but establishes the infrastructure every other spec depends on.

## User Stories

- **US-01.1**: As a user, I can launch the application on macOS and see a home screen with a clean, minimal interface.
- **US-01.2**: As a user, I can toggle between dark and light themes, and my preference persists across app restarts.
- **US-01.3**: As a user, I can navigate between different sections of the app (Home, Problem Bank, History, Settings) using a persistent navigation structure.

## Acceptance Criteria

- [ ] Flutter project builds and runs on macOS without errors
- [ ] Bundle identifier is `com.joaquinmx.preparewithatlas` (verified in `macos/Runner.xcodeproj` and `Info.plist`)
- [ ] `very_good_analysis` linter is active; `flutter analyze` returns zero warnings/errors
- [ ] Drift database initializes on first launch with all tables (Problems, InterviewSessions, StageNotes, WhiteboardSnapshots, Evaluations, AiProviderConfigs, AppSettings)
- [ ] go_router navigation works between Home, Problem Bank, History, and Settings placeholder screens
- [ ] Dark and light themes apply correctly with the defined color tokens
- [ ] Theme preference persists in AppSettings table across restarts
- [ ] macOS entitlements include `com.apple.security.network.client`
- [ ] All widget and unit tests pass (TDD: tests written before implementation)

## Functional Requirements

- **FR-01.1**: The app uses `MaterialApp.router` with go_router for declarative routing.
- **FR-01.2**: Route paths: `/` (Home), `/problems` (Problem Bank), `/history` (History), `/settings` (Settings), `/settings/ai` (AI Settings). All render placeholder screens initially.
- **FR-01.3**: Drift database is created at `~/Library/Application Support/PrepareWithAtlas/atlas.db`.
- **FR-01.4**: Database schema includes all 7 tables defined in the data model (see plan.md).
- **FR-01.5**: ThemeData is built from `AtlasColors`, `AtlasTypography`, and `AtlasSpacing` token classes.
- **FR-01.6**: A `SettingsController` (Riverpod StateNotifier) manages theme mode and persists it via Drift.
- **FR-01.7**: The home screen displays the app name, a navigation sidebar (or top bar), and empty-state placeholders for "Recent Sessions" and "Quick Start."

## Non-Functional Requirements

- **NFR-01.1**: Cold app startup time < 2 seconds on M1+ Mac.
- **NFR-01.2**: Database initialization (first launch) < 500ms.
- **NFR-01.3**: Theme switch is instant (no visible delay or flicker).
- **NFR-01.4**: Project follows feature-first folder structure with domain/data/application/presentation layers per feature.

## Edge Cases

- **EC-01.1**: Database file is corrupted or deleted between launches → app recreates it with empty tables, shows first-launch state.
- **EC-01.2**: App settings table is empty on first launch → defaults to system theme mode.
- **EC-01.3**: Unknown route path navigated to → redirect to `/` (Home).
