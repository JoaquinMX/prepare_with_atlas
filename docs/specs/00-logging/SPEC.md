# Spec 00 (Draft): Logging — SPEC.md

> **Status**: Draft — pending review and approval before implementation.

## Summary

This document defines the logging strategy for the application. Currently, the codebase uses two logging mechanisms (`dart:developer` and `package:logger`) with no centralized service, inconsistent patterns, and debug-only behavior that renders logs invisible in production builds. This spec establishes a unified, centralized logging approach.

## Current State

| Mechanism | Files | Notes |
|-----------|-------|-------|
| `dart:developer` | 9 | Debug-only (invisible in release), used in most features |
| `package:logger` | 1 | Only in `curated_problems_loader.dart` |

**Issues**:
- `dart:developer` logs are stripped/disabled in release builds
- No centralized logger service in `lib/core/`
- No log destination strategy (console only, no file output for macOS)
- Two different import patterns and APIs
- No centralized log level configuration

## User Stories

- **US-00.1**: As a developer, I can trace execution flow through the app via structured log events.
- **US-00.2**: As a developer/ops, I can search and filter logs by category, level, and timestamp.
- **US-00.3**: As a developer, errors include sufficient context (exception message, stack trace) for debugging.
- **US-00.4**: As a user, sensitive data (API keys, tokens, personal notes) is never logged.

## Functional Requirements

- **FR-00.1**: A centralized `AppLogger` service is created in `lib/core/logging/app_logger.dart`.
- **FR-00.2**: All logging uses `AppLogger` — no direct use of `dart:developer` or `package:logger` in feature code.
- **FR-00.3**: `AppLogger` wraps `package:logger` for its level-based filtering, multiple outputs, and production-safe behavior.
- **FR-00.4**: Each feature has a consistent log category matching its class name (e.g., `EvaluationController`, `WhiteboardController`).
- **FR-00.5**: Log messages follow the pattern: `event: detail1, detail2` (colon separator, comma-separated details).
- **FR-00.6**: Error logs always include the `error:` parameter with the exception object.
- **FR-00.7**: Sensitive data (AI API keys, session tokens, full stage notes) is explicitly excluded from log output.

## Non-Functional Requirements

- **NFR-00.1**: Log levels: DEBUG (0), INFO (500), WARNING (900), ERROR (1000), SEVERE (1200).
- **NFR-00.2**: In debug mode, logs are printed to console. In release mode, logs are written to a rotating file in `~/Library/Logs/<app-name>/`.
- **NFR-00.3**: Log rotation: max 5 files, 5MB each.
- **NFR-00.4**: Performance: logging does not block the main isolate.

## Log Categories by Feature

| Feature | Category | Status |
|---------|----------|--------|
| Evaluation | `EvaluationController` | Pending migration |
| Interview Session | `SessionController`, `DictationController` | Pending migration |
| Whiteboard | `WhiteboardController` | Pending migration |
| AI Provider | `AiProviderController` | Pending migration |
| Problem Bank | `CuratedProblemsLoader` | Pending migration |

## Migration Plan

1. **Phase 1**: Create `lib/core/logging/app_logger.dart` with `package:logger` wrapper.
2. **Phase 2**: Migrate `curated_problems_loader.dart` (only file using `package:logger`).
3. **Phase 3**: Migrate feature controllers in order of priority: Evaluation → AI Provider → Interview Session → Whiteboard.
4. **Phase 4**: Update all specs to reference `FR-00.x` requirements instead of inline logging patterns.

## Edge Cases

- **EC-00.1**: Third-party library logging (e.g., Drift, provider) — route through `AppLogger` if possible, otherwise allow library defaults.
- **EC-00.2**: Crash during logging (e.g., disk full) — fail silently to avoid cascading failures.
