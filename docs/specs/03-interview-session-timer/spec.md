# Spec 03: Interview Session & Timer — spec.md

## Summary

The core interview simulation experience. Users configure and run mock system design interviews — either a full 5-stage interview or a single-stage drill. A configurable countdown timer tracks time per stage with three behavior modes. The workspace provides a text notes panel alongside the whiteboard (Spec 04) in a resizable split layout. Like a real interview, the user sees only the problem statement, the current stage name, and the timer — no reference hints, no topic lists, no cheat sheets.

## User Stories

- **US-03.1**: As a user, I can set up a new interview session by selecting a problem, choosing full or single-stage mode, and configuring timer behavior.
- **US-03.2**: As a user, I can adjust the duration for each stage before starting.
- **US-03.3**: As a user, during an interview I can see which stage I'm on, how much time remains, and navigate between stages.
- **US-03.4**: As a user, I can type notes for each stage in a text panel, and my notes auto-save.
- **US-03.5**: As a user, I can pause the timer if I need a break.
- **US-03.6**: As a user, I receive a visual warning when time is running low on a stage.
- **US-03.7**: As a user, I can end my session early and proceed to evaluation.
- **US-03.8**: As a user, I can abandon a session without evaluation.
- **US-03.9**: As a user, I can dictate notes using in-app speech-to-text, even while interacting with the whiteboard panel.
- **US-03.10**: As a user, I can see a visual indicator when dictation is active and toggle it on/off with a mic button in the notes panel.

## Acceptance Criteria

- [ ] Session setup screen allows: problem selection, mode (full/single), timer behavior (soft/auto-advance/hard-stop), per-stage duration sliders
- [ ] Interview workspace displays: problem title in the top bar, problem description pre-placed as a movable text element in the whiteboard at session start, stage progress bar with stage names, countdown timer, notes panel (left ~40%), whiteboard panel (right ~60%)
- [ ] Stage progress bar highlights current stage and shows completed stages
- [ ] Timer counts down and displays in MM:SS format (JetBrains Mono font)
- [ ] Timer color changes: accent (normal) → warning/amber (≤60s) → danger/red (overtime)
- [ ] Soft warning mode: timer goes negative, shows overtime, user manually ends
- [ ] Auto-advance mode: shows grace period countdown (30s default), then advances to next stage
- [ ] Hard stop mode: stage ends immediately at 0:00
- [ ] Notes auto-save to database with 1-second debounce
- [ ] Mic toggle button appears in `StageNotesPanel` header; tapping starts listening, recognized words append at cursor position in notes
- [ ] Once activated, the microphone stays open until the user taps the mic button again, the stage transitions, or the session ends — silence pauses and platform timeouts do not close the mic
- [ ] Tapping mic again stops listening; visual indicator (accent color + pulse animation) shows when dictation is active
- [ ] Dictation works regardless of which panel (notes or whiteboard) has focus
- [ ] Dictation state persists across stage transitions (in-flight dictation is finalised and saved before advancing)
- [ ] Microphone permission request shown on first use; denial handled gracefully with info message
- [ ] **NO reference sidebar, topics list, techniques list, or key insights are shown during the interview** — only the problem statement, stage name, timer, notes field, and whiteboard
- [ ] Pause button freezes timer; resume continues
- [ ] "End Session" button saves all data and navigates to evaluation (Spec 06)
- [ ] "Abandon" button confirms via dialog, then navigates home without evaluation
- [x] Split panel is draggable to resize notes vs. whiteboard area (divider uses CrossAxisAlignment.stretch + MouseRegion with resize cursor)
- [ ] All unit and widget tests pass

## Functional Requirements

- **FR-03.1**: `InterviewStage` enum with 5 values, each carrying **only**: display name and default duration (min/max/default). No topics, techniques, technologies, or key insights — the CSV's additional columns are not used in the UI.
- **FR-03.2**: `InterviewSession` model: id, problemId, mode (full/single_stage), focusStage (nullable), timerBehavior, status (in_progress/completed/abandoned), timestamps.
- **FR-03.3**: `StageNote` model: id, sessionId, stage, notes text, timerDurationSeconds, timeSpentSeconds, updatedAt.
- **FR-03.4**: `SessionController` orchestrates: session creation, stage transitions, notes saving, session completion/abandonment.
- **FR-03.5**: `StageTimerController` manages countdown with state machine (Idle → Running → Warning → GracePeriod/Overtime/StageEnded).
- **FR-03.6**: In full mode, completing a stage auto-loads the next stage's timer and clears the notes panel (previous notes preserved in DB).
- **FR-03.7**: In single-stage mode, only the selected stage is available; completing it goes directly to evaluation.
- **FR-03.8**: Session data persists on every stage transition and every notes auto-save.
- **FR-03.9**: `DictationController` manages `SpeechToText` lifecycle: `startListening()`, `stopListening()`, `toggleListening()`. Recognized text is appended to the active stage's notes at the cursor position. The controller is scoped to the interview session and survives stage transitions.
- **FR-03.10**: `StageNotesPanel` renders a mic toggle button in its header. When dictation is active the button shows an accent-coloured icon with a subtle pulse animation. The previous "Fn Fn to dictate" tooltip is replaced with a "Tap mic to dictate" tooltip on the button. Dictation works regardless of which panel (notes or whiteboard) has focus.
- **FR-03.11**: Dictation transcript is stored as part of `StageNote.notes` text (interleaved with typed text, not stored separately). The notes field is the canonical input for AI evaluation whether the text was typed or dictated.

## Non-Functional Requirements

- **NFR-03.1**: Timer updates at exactly 1-second intervals with ≤10ms jitter.
- **NFR-03.2**: Notes auto-save debounce: 1 second after last keystroke.
- **NFR-03.3**: Stage transition (saving + loading next) completes in < 200ms.
- **NFR-03.4**: Split panel drag is smooth at 60fps.
- **NFR-03.5**: Dictation latency from speech to text in notes field ≤ 500ms on macOS (native speech recognizer).
- **NFR-03.6**: Dictation continues working even when WebView (whiteboard) has focus — no dependency on text field focus.

## Edge Cases

- **EC-03.1**: User closes app during active session → session saved as "in_progress," can be resumed on next launch (V2 consideration; V1: mark as abandoned).
- **EC-03.2**: Timer reaches 0 in soft mode and user types for 30+ minutes overtime → timer shows negative time, no forced stop.
- **EC-03.3**: User tries to skip to a stage beyond the last → "End Session" flow triggers instead.
- **EC-03.4**: User sets stage duration to minimum (3 min) → warning threshold adjusts proportionally (30s for short stages).
- **EC-03.5**: User pastes very long text into notes → no truncation during session; truncation only at evaluation prompt assembly.
- **EC-03.6**: Grace period expires during auto-advance but user is mid-sentence → text is saved before advancing.
- **EC-03.7**: Microphone permission denied → show info message "Microphone access is needed for dictation. Enable it in System Settings → Privacy & Security → Microphone." and disable the mic button.
- **EC-03.8**: Platform-level dictation timeout (listenFor limit reached) → automatically restart listening so the microphone stays open. No status change is shown to the user; the pulse animation continues uninterrupted.
- **EC-03.9**: No speech detected for 5 seconds (pauseFor silence timeout) → automatically restart listening. The microphone stays open; the user does not need to re-tap the mic button after a pause in speech.
- **EC-03.10**: Stage transition while dictation is active → stop listening, save current notes, then advance. Do not lose in-flight dictation.
- **EC-03.11**: Very fast speech → partial results replace previous partial result at cursor until final result is confirmed.
