# Spec 08: App Settings — spec.md

## Summary

Central settings screen for app-wide preferences: theme mode, default timer configurations, and navigation to AI provider settings. Serves as the user's control center for customizing their PrepareWithAtlas experience.

## User Stories

- **US-08.1**: As a user, I can toggle between system, light, and dark themes.
- **US-08.2**: As a user, I can set my preferred default timer behavior (soft/auto-advance/hard-stop) so I don't configure it every session.
- **US-08.3**: As a user, I can set default stage durations that pre-populate in session setup.
- **US-08.4**: As a user, I can navigate to AI provider settings from the main settings.
- **US-08.5**: As a user, I can see app version and "About" information.

## Acceptance Criteria

- [ ] Settings screen accessible from home navigation
- [ ] Theme picker with 3 options: System, Light, Dark — changes apply immediately
- [ ] Default timer behavior selector persists across app restarts
- [ ] Default stage durations configurable with sliders (within min/max bounds per stage)
- [ ] "AI Provider" navigation item goes to AI Settings (Spec 05)
- [ ] About section shows app version, build number, and credits
- [ ] All preferences persist in AppSettings table
- [ ] All tests pass

## Functional Requirements

- **FR-08.1**: Reuses `SettingsController` from Spec 01, extended with timer defaults.
- **FR-08.2**: `AppSettings` model extended: themeMode, defaultTimerBehavior, defaultStageDurations (Map<InterviewStage, int>).
- **FR-08.3**: Settings changes apply immediately (no "Save" button).

## Non-Functional Requirements

- **NFR-08.1**: Theme switch is instant (< 100ms).
- **NFR-08.2**: Settings persistence is immediate (save on change).

## Edge Cases

- **EC-08.1**: Corrupted settings → reset to defaults silently.
- **EC-08.2**: Stage duration set to value outside min/max → clamp to nearest valid value.
