# Spec 03: Interview Session & Timer — tasks.md

## Phase 1: Domain Models (TDD)

- **T001**: Write tests for `InterviewStage` enum — verify: 5 values exist, each has ONLY displayName, defaultDuration, minDuration, maxDuration. Verify there are no topic/technique/insight fields.
- **T002**: Implement `InterviewStage` enum — 5 values with names and durations from CSV: `requirementGathering` (5/10/7 min), `backOfEnvelopeEstimation` (3/5/5 min), `highLevelDesign` (10/15/12 min), `deepDive` (15/20/17 min), `scalingAndBottlenecks` (5/10/7 min).
- **T003**: Write tests for `TimerBehavior` enum — verify: 3 values (softWarning, warningAutoAdvance, hardStop).
- **T004**: Implement `TimerBehavior` enum.
- **T005**: Write tests for `TimerConfig` freezed model — verify: creation, defaults per stage, warningThresholdSeconds defaults to 60, gracePeriodSeconds defaults to 30.
- **T006**: Implement `TimerConfig` freezed model.
- **T007**: Write tests for `InterviewSession` freezed model — verify: creation, status transitions, JSON serialization.
- **T008**: Implement `InterviewSession` freezed model.
- **T009**: Write tests for `StageNote` freezed model — verify: creation, copyWith for notes update, JSON serialization.
- **T010**: Implement `StageNote` freezed model.

## Phase 2: Timer Controller (TDD)

- **T011**: Write tests for `StageTimerController` — idle state: verify initial state is idle with no active stage.
- **T012**: Write tests for `StageTimerController` — running state: verify startStage sets remaining to duration, tick decrements by 1 each second.
- **T013**: Write tests for `StageTimerController` — pause/resume: verify pause stops decrementing, resume continues.
- **T014**: Write tests for `StageTimerController` — warning state: verify warning triggers when remaining ≤ warningThreshold.
- **T015**: Write tests for `StageTimerController` — soft warning mode: verify timer goes negative when remaining hits 0, stays in Overtime state.
- **T016**: Write tests for `StageTimerController` — auto-advance mode: verify grace period starts at 0, grace decrements, stage ends when grace hits 0.
- **T017**: Write tests for `StageTimerController` — hard stop mode: verify stage ends immediately when remaining hits 0.
- **T018**: Write tests for `StageTimerController` — skipToNextStage: verify records time spent, advances to next stage.
- **T019**: Implement `StageTimerController` (StateNotifier) with full state machine logic.

## Phase 3: Session Data Layer (TDD)

- **T020**: Define `SessionRepository` abstract class with methods: `create()`, `getById()`, `getAll()`, `update()`, `delete()`, `watchAll()`, `saveStageNote()`, `getStageNotes(sessionId)`.
- **T021**: Write tests for `DriftSessionRepository` — verify: create session, get by id, update status, save stage note, get stage notes by session, cascade delete.
- **T022**: Implement `DriftSessionRepository`.

## Phase 4: Session Controller (TDD)

- **T023**: Write tests for `SessionController` — verify: startFullSession creates session with all 5 stages, startSingleStage creates session with 1 stage.
- **T024**: Write tests for `SessionController` — verify: advanceToNextStage saves current notes + time, loads next stage; endSession sets status to completed.
- **T025**: Write tests for `SessionController` — verify: abandonSession sets status to abandoned, autoSaveNotes debounces and persists.
- **T026**: Implement `SessionController` (StateNotifier).

## Phase 5: Presentation (TDD)

- **T027**: Write widget tests for `SessionSetupScreen` — verify: problem selector, mode toggle (full/single), timer behavior picker, duration sliders, "Begin" button.
- **T028**: Implement `SessionSetupScreen`.
- **T029**: Write widget tests for `TimerDisplay` — verify: shows MM:SS, color changes at warning/overtime thresholds, pause button toggles.
- **T030**: Implement `TimerDisplay` widget.
- **T031**: Write widget tests for `StageProgressBar` — verify: 5 segments, current highlighted, completed dimmed, clickable for manual skip.
- **T032**: Implement `StageProgressBar` widget.
- **T033**: Write widget tests for `InterviewScreen` — verify: renders problem statement header, split layout, notes panel, stage bar, timer, action buttons (pause, skip, end, abandon). Verify NO reference sidebar, topics list, or techniques list is rendered anywhere.
- **T034**: Implement `InterviewScreen` with split layout (notes left, whiteboard placeholder right), problem statement header, stage bar, timer, and action bar.
- **T035**: Implement `StageNotesPanel` with plain text input and auto-save (no reference sidebar).

## Phase 6: Dictation (TDD)

- **T036**: Add `speech_to_text` to `pubspec.yaml`; add `com.apple.security.device.audio-input` entitlement to both `DebugProfile.entitlements` and `Release.entitlements`; add `NSMicrophoneUsageDescription` to `Info.plist`.
- **T037**: Write tests for `DictationController` — verify: start/stop listening, permission denied sets error state with message, recognition results append text string via callback, auto-stop on silence timeout (5s), stage transition stops and finalises.
- **T038**: Implement `DictationController` (Riverpod StateNotifier) using `SpeechToText`. State: `DictationState` (idle / listening / stopped / error with message). Methods: `startListening()`, `stopListening()`, `toggleListening()`. Callback: `onResult(String text, {bool isFinal})` — partial results replace previous partial at cursor; final results commit.
- **T039**: Write tests for `DictationProviders` — verify: provider creates controller, state transitions propagate, controller is scoped to interview session lifecycle.
- **T040**: Implement `DictationProviders` (Riverpod providers for `DictationController`).
- **T041**: Update `StageNotesPanel` — add mic toggle button in header (accent-coloured with pulse animation when listening), wire to `DictationController`, append recognized text to notes at cursor position, replace "Fn Fn to dictate" tooltip with "Tap mic to dictate" tooltip on button, show "Microphone access needed" info when permission denied.
- **T042**: Write widget tests for updated `StageNotesPanel` — verify mic button renders, tapping toggles dictation state, recording indicator (pulse) shows when listening, recognised text appends to notes field, permission-denied state shows info message.
- **T043**: Update `InterviewScreen` — call `DictationController.stopListening()` on session end/abandon before navigation.
