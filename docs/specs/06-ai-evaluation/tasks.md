# Spec 06: AI Evaluation — tasks.md

## Phase 1: Domain Model (TDD)

- **T001**: Write tests for `EvaluationResult` freezed model — verify: creation with all fields, scorecard map, strengths/improvements lists, JSON serialization, clamping scores to 0-10.
- **T002**: Implement `EvaluationResult` freezed model.
- **T003**: Define `EvaluationRepository` abstract class: `save()`, `getBySessionId()`, `getAll()`, `delete()`.

## Phase 2: Prompt Engineering (TDD)

- **T004**: Write tests for `buildSystemPrompt()` — verify: contains role instruction, JSON output format specification, scoring dimensions list, and scoring rubric.
- **T005**: Implement `evaluation_system_prompt.dart` with system prompt template.
- **T006**: Write tests for `buildUserPrompt()` — verify: includes problem statement, includes all stage notes with stage names and time spent, includes reference solution when provided, omits reference when null. Notes under 20,000 chars are passed through unchanged. Notes over 20,000 chars use middle-truncation keeping first ~10,000 and last ~10,000 chars with marker.
- **T007**: Implement `evaluation_user_prompt.dart` with user prompt template and middle-truncation helper.
- **T008**: Write tests for `problem_generation_prompt.dart` — verify: includes difficulty/category parameters, specifies JSON output format matching Problem model.
- **T009**: Implement `problem_generation_prompt.dart`.

## Phase 3: Response Parsing (TDD)

- **T010**: Write tests for `ResponseParser.parse()` — verify: valid JSON parsed correctly, scores extracted, narrative preserved, strengths/improvements as lists.
- **T011**: Write tests for `ResponseParser.parse()` — edge cases: scores outside 0-10 clamped, missing dimensions shown as N/A (omitted from scorecard map), extra dimensions ignored.
- **T012**: Write tests for `ResponseParser.regexFallback()` — verify: extracts scores from text like "Requirements Gathering: 8/10", extracts narrative paragraphs.
- **T013**: Implement `ResponseParser` with JSON parsing and regex fallback.

## Phase 4: Data Layer (TDD)

- **T014**: Write tests for `DriftEvaluationRepository` — verify: save + getBySessionId round-trip, stores raw response JSON, stores scorecard JSON separately.
- **T015**: Implement `DriftEvaluationRepository`.

## Phase 5: Controller (TDD)

- **T016**: Write tests for `EvaluationController` — verify: requestEvaluation builds prompt with all session data, calls AIProvider.complete with system+user+image, parses response, saves to repository.
- **T017**: Write tests for `EvaluationController` — error handling: network timeout triggers retry (up to 2x), parse failure triggers regexFallback, total failure emits error state.
- **T018**: Write tests for `EvaluationController` — verify: no AI provider configured emits specific error, no whiteboard screenshot sends text-only prompt.
- **T019**: Implement `EvaluationController` (StateNotifier).

## Phase 6: Presentation (TDD)

- **T020**: Write widget tests for `ScoreCardWidget` — verify: renders 7 dimension bars, colors match score ranges (red/yellow/green), overall score prominent, N/A shown for unevaluated dimensions.
- **T021**: Implement `ScoreCardWidget`.
- **T022**: Write widget tests for `EvaluationResultScreen` — verify: scorecard displayed, narrative rendered as Markdown, strengths/improvements as bullet lists, reference comparison section shown only for curated problems, "Home" and "Retry" buttons present.
- **T023**: Implement `EvaluationResultScreen`.
- **T024**: Write widget tests for `EvaluationLoadingScreen` — verify: progress indicator, status text updates, error state shows retry button.
- **T025**: Implement `EvaluationLoadingScreen`.

## Phase 7: Integration

- **T026**: Wire evaluation into `SessionController` — endSession() triggers navigation to EvalLoadingScreen, passes session data to EvaluationController.
- **T027**: End-to-end test: complete a mock session → evaluation triggers → verify prompt includes notes + screenshot → verify result displayed correctly.
