# Spec 07: Session History & Progress — spec.md

## Summary

Users can browse their past interview sessions, see scores at a glance, and review session details including notes, whiteboard drawings, and full evaluation feedback. Supports **retrying the same problem** to practice it multiple times and compare progress across attempts. Also supports re-evaluating a past session with a different AI provider for a second opinion.

## User Stories

- **US-07.1**: As a user, I can see a list of all my past **completed** interview sessions with date, problem name, and overall score. Abandoned and in-progress sessions are excluded from History.
- **US-07.2**: As a user, I can open a past session to review my notes for each stage.
- **US-07.3**: As a user, I can view my whiteboard drawing from a past session in read-only mode.
- **US-07.4**: As a user, I can view the full evaluation from a past session — scorecard, strengths, areas for improvement, detailed narrative, and reference comparison (curated problems only).
- **US-07.5**: As a user, I can **retry a problem** — start a fresh interview session on the same problem I attempted before, without needing to find it again in the Problem Bank.
- **US-07.6**: As a user, I can see **all my attempts at the same problem** grouped together, with a score trend showing whether I'm improving.
- **US-07.7**: As a user, I can view a **side-by-side progress comparison** between my first attempt and my latest attempt on a problem — with scorecard diff, time-spent changes, and narrative delta.
- **US-07.8**: As a user, I can re-evaluate a past session with a different AI provider to get a second opinion.
- **US-07.9**: As a user, I can delete past sessions I no longer need.

## Acceptance Criteria

- [ ] History screen shows only **ended sessions** (status = completed). Abandoned and in-progress sessions are excluded from all history queries.
- [ ] History screen has two views: "All Sessions" (flat list, newest first) and "By Problem" (grouped by problem with attempt count and trend)
- [ ] "By Problem" view shows each problem with: problem title, number of attempts, first score, latest score, trend arrow (↑/↓/→)
- [ ] Tapping a problem in "By Problem" view expands to show all attempts with dates and scores
- [ ] Session detail screen has three tabs: Notes (per stage), Whiteboard (read-only Excalidraw), Evaluation (scorecard + strengths + areas for improvement + detailed feedback narrative + reference comparison for curated problems)
- [ ] Session detail screen has a **"Retry This Problem"** button that starts a new session with the same problem (goes to Session Setup pre-populated)
- [ ] Session detail screen has a **"Compare to Previous Attempt"** button (visible only when there are 2+ attempts) that opens a side-by-side comparison view
- [ ] Comparison view shows: scorecard diff (each dimension with delta), time-spent delta per stage, narrative feedback side-by-side
- [ ] Re-evaluate button triggers new evaluation and stores alongside original (multiple evaluations per session)
- [ ] Delete session shows confirmation dialog, cascade-deletes notes, whiteboard, and evaluations
- [ ] Empty history state shows encouraging message and link to start first session
- [ ] All tests pass

## Functional Requirements

- **FR-07.1**: `SessionHistoryScreen` supports two view modes: flat list (by date) and grouped by problem. **Only sessions with status `completed` are included**; sessions with status `abandoned` or `in_progress` are filtered out at the repository level.
- **FR-07.2**: Grouped view uses a repository query that joins sessions with problems and aggregates by `problem_id`, returning: problem, attempt count, first score, latest score, date range.
- **FR-07.3**: `SessionDetailScreen` shows: stage-by-stage notes (read-only text), whiteboard (Excalidraw in view mode), evaluation results (scorecard, strengths, improvements, narrative, reference comparison), "Retry This Problem" button, and (when applicable) "Compare to Previous Attempt" button.
- **FR-07.4**: "Retry This Problem" creates a new interview session with the same `problem_id` and navigates to Session Setup. Previous session remains untouched.
- **FR-07.5**: "Compare to Previous Attempt" opens a `ProgressComparisonScreen` showing:
  - Side-by-side scorecard with delta indicators (e.g., "+2", "-1", color-coded)
  - Time-spent delta per stage
  - Both narrative feedbacks side-by-side
  - Overall score trend visual
- **FR-07.6**: Re-evaluation creates a new `Evaluations` row linked to the same session — does not overwrite the original.
- **FR-07.7**: Delete cascade: removing a session deletes its `StageNotes`, `WhiteboardSnapshots`, and `Evaluations`. Problem is not deleted (can have other attempts).

## Non-Functional Requirements

- **NFR-07.1**: History list loads in < 500ms for 100+ sessions.
- **NFR-07.2**: Session detail loads in < 1 second including whiteboard restore.
- **NFR-07.3**: Grouped-by-problem aggregation query < 200ms for 500+ sessions.
- **NFR-07.4**: Progress comparison view renders in < 500ms including both whiteboards (optional, collapsed by default).

## Edge Cases

- **EC-07.1**: Session has no evaluation (evaluation failed after session completed) → show "Not evaluated" badge, offer to evaluate now. Excluded from progress comparison. (Abandoned sessions never appear in History at all; see FR-07.1.)
- **EC-07.2**: Session has multiple evaluations → show latest by default, with dropdown to view older ones.
- **EC-07.3**: Whiteboard data missing → show "No whiteboard data" placeholder.
- **EC-07.4**: Problem has only 1 attempt → "Compare to Previous Attempt" button hidden.
- **EC-07.5**: Problem has 3+ attempts → "Compare to Previous" compares latest vs second-latest by default, with dropdown to pick any other attempt.
- **EC-07.6**: Retrying a problem that has been deleted from the database → show error, offer to view past attempts only.
- **EC-07.7**: Comparing attempts with different scorecard dimensions (e.g., old eval has different categories) → show missing dimensions as "N/A" in the diff view.
