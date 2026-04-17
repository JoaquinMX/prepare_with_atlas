# Spec 08: App Settings — tasks.md

## Phase 1: Domain Model (TDD)

- **T001**: Write tests for extended `AppSettings` model — verify: defaultTimerBehavior, defaultStageDurations map, JSON serialization.
- **T002**: Extend `AppSettings` model and Drift table with new fields. Run migration.

## Phase 2: Controller (TDD)

- **T003**: Write tests for `SettingsController` extensions — verify: updateTimerBehavior persists, updateStageDuration persists, getDefaults returns correct values.
- **T004**: Update `SettingsController` with new methods.

## Phase 3: Presentation (TDD)

- **T005**: Write widget tests for `SettingsScreen` — verify: theme picker renders and switches, timer behavior selector works, stage duration sliders within bounds, AI Settings nav works, About section renders.
- **T006**: Implement `SettingsScreen`.

## Phase 4: Integration

- **T007**: Wire settings screen navigation from HomeScreen sidebar.
