# Spec 07: Session History & Progress — tasks.md

## Phase 1: Data Queries & Aggregation (TDD)

- **T001**: Write tests for flat history query — verify: returns all sessions with latest evaluation score, sorted by date descending, includes problem title via join.
- **T002**: Implement flat history query in `DriftSessionRepository.watchHistory()`.
- **T003**: Write tests for grouped-by-problem query — verify: groups sessions by problem_id, returns `ProblemAttempts` with attempt count, first score, latest score, date range, ordered by latest attempt date desc.
- **T004**: Implement grouped query in `DriftSessionRepository.watchHistoryByProblem()`.
- **T005**: Write tests for single-problem attempts query — verify: returns all attempts for a given problem_id ordered by date asc with their evaluations.
- **T006**: Implement `DriftSessionRepository.getAttemptsForProblem(problemId)`.

## Phase 2: Domain Models (TDD)

- **T007**: Write tests for `ProblemAttempts` freezed model — verify: problem, attempts list, firstScore, latestScore, trend (up/down/flat) calculated from first vs latest.
- **T008**: Implement `ProblemAttempts` freezed model.
- **T009**: Write tests for `ProgressDiff` freezed model — verify: computes scorecard deltas (per dimension), time-spent deltas (per stage), handles missing dimensions as N/A.
- **T010**: Implement `ProgressDiff` freezed model with static `from(EvaluationResult prior, EvaluationResult current)` factory.

## Phase 3: Controllers (TDD)

- **T011**: Write tests for `HistoryController` — verify: flat view loads sessions, grouped view loads ProblemAttempts, toggle switches state, delete cascades.
- **T012**: Implement `HistoryController` (StateNotifier).
- **T013**: Write tests for `ComparisonController` — verify: loads two evaluations, computes ProgressDiff, handles missing evaluations gracefully.
- **T014**: Implement `ComparisonController` (StateNotifier).

## Phase 4: Presentation (TDD)

- **T015**: Write widget tests for `SessionHistoryScreen` flat view — verify: renders session list with problem title/date/score, empty state shown when no sessions, tapping navigates to detail.
- **T016**: Write widget tests for `SessionHistoryScreen` grouped view — verify: renders problem groups with attempt count + first/latest score + trend arrow, tapping expands attempts, tapping attempt navigates to detail.
- **T017**: Implement `SessionHistoryScreen` with view mode toggle (flat/grouped).
- **T018**: Write widget tests for `SessionDetailScreen` — verify: tabs render (Notes, Whiteboard, Evaluation); tabs show correct data; "Retry This Problem" button visible and navigates to session setup with problemId; "Compare to Previous Attempt" button hidden when <2 attempts, visible when ≥2.
- **T019**: Implement `SessionDetailScreen` with tabs, retry button, and compare button.
- **T020**: Write widget tests for `ProgressComparisonScreen` — verify: side-by-side scorecards, delta indicators color-coded (green positive, red negative), time-spent deltas per stage, narrative feedbacks shown side-by-side, trend summary at top.
- **T021**: Implement `ProgressComparisonScreen`.

## Phase 5: Retry and Re-Evaluate Actions (TDD)

- **T022**: Write tests for retry flow — verify: tapping "Retry This Problem" creates new session with same problemId, navigates to Session Setup, does not modify existing session.
- **T023**: Wire retry button to navigate to Session Setup with `problemId` query param.
- **T024**: Write tests for re-evaluation flow — verify: triggers new evaluation with existing session data, stores as new evaluation row, does not overwrite original.
- **T025**: Implement re-evaluate button in SessionDetailScreen, wired to EvaluationController.
- **T026**: Write tests for delete session — verify: cascade deletes notes, whiteboard, evaluations; problem remains (for other attempts).
- **T027**: Implement delete with confirmation dialog.

## Phase 6: Integration

- **T028**: End-to-end test: complete a session → visit history → retry same problem → complete again → verify both attempts appear in grouped view → open comparison → verify deltas computed correctly.
