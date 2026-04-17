# Spec 06: AI Evaluation — spec.md

## Summary

After completing an interview session, the user's notes and whiteboard drawing are sent to the configured AI provider for expert evaluation. The AI returns a structured scorecard with scores per dimension (0-10) and a narrative with strengths, improvement areas, and actionable advice. For curated problems, the AI also compares against the reference solution.

## User Stories

- **US-06.1**: As a user, after completing my interview I see a loading screen while the AI evaluates my work.
- **US-06.2**: As a user, I receive a scorecard showing my score (0-10) across 7 dimensions with visual indicators.
- **US-06.3**: As a user, I receive written narrative feedback highlighting my strengths and areas for improvement.
- **US-06.4**: As a user, if I practiced a curated problem, I can see how my approach compares to the reference solution.
- **US-06.5**: As a user, I can retry evaluation if it fails (network error, timeout).
- **US-06.6**: As a user, I can re-evaluate a past session with a different AI provider.
- **US-06.7**: As a user, when I dictate notes while whiteboarding, my spoken words are automatically included in the AI evaluation alongside my diagram.

## Acceptance Criteria

- [ ] Evaluation loading screen shows progress indicator with status text and a live elapsed-time counter ("Xs elapsed · typically 30–90 seconds")
- [ ] Scorecard displays 7 dimensions with score bars: Requirements Gathering, Estimation Quality, High-Level Design, Deep Dive Quality, Scaling Awareness, Communication Clarity, Overall
- [ ] Each score bar is color-coded: red (0-3), yellow (4-6), green (7-10)
- [ ] Narrative feedback renders as formatted Markdown below the scorecard
- [ ] Strengths and improvements shown as bullet point lists
- [ ] Reference comparison section shown only for curated problems
- [ ] "Retry" button available on evaluation failure
- [ ] Evaluation result persists in database for history review
- [ ] Whiteboard screenshot is included in the AI prompt as an image
- [ ] All tests pass

## Functional Requirements

- **FR-06.1**: `EvaluationController` assembles the evaluation prompt from: problem statement, stage notes (all stages, which may include voice-dictated text), whiteboard screenshot (PNG), reference solution (if curated problem). Stage notes are the canonical input regardless of whether text was typed or dictated — the AI evaluator does not distinguish the input method.
- **FR-06.2**: System prompt instructs AI to return JSON matching `EvaluationResult` schema with scorecard, strengths, improvements, and narrative.
- **FR-06.3**: `EvaluationResult` model: scorecard (Map<String, int>), overallScore (int), strengths (List<String>), improvements (List<String>), narrative (String, markdown), referenceComparison (String?, only for curated).
- **FR-06.4**: If AI response is valid JSON → parse directly. If malformed → attempt regex extraction of scores and narrative. If both fail → return error state.
- **FR-06.5**: Evaluation result is saved to `Evaluations` table with provider/model used, raw response, and parsed result.
- **FR-06.6**: Timeout: 120 seconds. Retry: up to 2 automatic retries with exponential backoff on network errors.
- **FR-06.7**: Whiteboard screenshot compressed to ≤1200px width before sending.
- **FR-06.8**: Per-stage notes are sent to the AI in FULL by default — no truncation applied. The prior concern about 2,000-char limits was too aggressive; system design notes for a stage can legitimately reach 5,000-15,000 characters (equivalent to 800-2,500 words). Truncation risks losing critical reasoning that the evaluator needs to score the user accurately.
- **FR-06.9**: Only if the **total prompt** (system + user + all stages) risks exceeding the model's context window, a soft cap of **20,000 characters per stage** is applied. If exceeded, the middle of the notes is truncated (keeping the first and last ~10,000 chars + a "[...content truncated for length...]" marker). First and last thirds are preserved because they usually contain the user's opening plan and final conclusion/trade-offs.
- **FR-06.10**: Context-window strategy: use models with large windows by default (GPT-4o 128K, Claude Sonnet 200K, Gemini 1.5 1M). For Ollama, warn the user if their selected model has < 32K context.
- **FR-06.11**: In single-stage drill mode, only the dimensions explicitly mapped to the practiced stage are scored. The stage-to-dimension mapping is:
  - `requirementGathering` → `requirementsGathering`, `communicationClarity`, `overall`
  - `backOfEnvelopeEstimation` → `estimationQuality`, `communicationClarity`, `overall`
  - `highLevelDesign` → `highLevelDesign`, `communicationClarity`, `overall`
  - `deepDive` → `deepDiveQuality`, `communicationClarity`, `overall`
  - `scalingAndBottlenecks` → `scalingAwareness`, `communicationClarity`, `overall`
  All dimensions not listed for the focused stage MUST be omitted from the scorecard JSON entirely. The AI must not infer or invent scores for dimensions that belong to other stages. `communicationClarity` is cross-cutting (scored in every stage). `overall` always reflects the focused stage only.

## Non-Functional Requirements

- **NFR-06.1**: Evaluation round-trip (prompt assembly → AI call → parse → save) < 2 minutes.
- **NFR-06.2**: Prompt token count logged for cost awareness via `dart:developer` log (name: `EvaluationController`).
- **NFR-06.3**: Raw AI response stored for debugging.
- **NFR-06.4**: `EvaluationController` emits granular `statusText` updates throughout the pipeline: "Assembling your evaluation...", "Sending to AI for analysis...", "Analysing your response...", "Saving results...", and "Retrying (attempt N of M)..." on retries. The loading screen reflects these in real time.
- **NFR-06.5**: `EvaluationController` logs structured events at key pipeline stages (start, prompt built, AI responded with elapsed ms + token counts, parse failure at SEVERE, success with total elapsed + score). On each retry attempt, log the specific exception message and stack trace at WARNING level before applying backoff. Log "all retries exhausted" at SEVERE with total elapsed time.

## Edge Cases

- **EC-06.1**: AI provider not configured → redirect to AI Settings with message.
- **EC-06.2**: AI returns scores outside 0-10 range → clamp to 0-10.
- **EC-06.3**: AI returns extra/missing scorecard dimensions → absent dimensions are shown as N/A (omitted from the scorecard map), extra dimensions are ignored.
- **EC-06.4**: No whiteboard screenshot available (user didn't draw anything) → send prompt without image, note in evaluation that no diagram was provided.
- **EC-06.5**: Session has only 1 stage (single-stage mode) → evaluation prompt includes only that stage's notes; only the dimensions mapped to that stage are scored (see FR-06.11). All other dimensions are omitted from the scorecard (shown as N/A in the UI).
- **EC-06.6**: Very long notes (> 20,000 chars per stage) → middle-truncate (keep first ~10,000 and last ~10,000 chars with a "[...content truncated for length...]" marker). First/last thirds are preserved to keep the user's opening plan and final trade-offs visible to the evaluator. Log a warning for the user after evaluation.
- **EC-06.7**: Total prompt (all stages combined) risks exceeding model context window → apply EC-06.6 truncation more aggressively per-stage, or warn user and suggest switching to a larger-context model.
- **EC-06.8**: Stage notes contain primarily dictated text with no manual edits → still evaluated normally. The evaluation prompt does not distinguish typed vs. dictated content.
