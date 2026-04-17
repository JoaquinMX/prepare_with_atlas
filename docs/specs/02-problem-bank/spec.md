# Spec 02: Problem Bank — spec.md

## Summary

A library of system design interview problems presented the way a real interviewer would present them: **just the problem title, nothing else**. No topic hints, no category tags, no difficulty badges — because real interviews don't come with cheat sheets. Problems are organized into three experience-level sections so users can self-select an appropriate challenge: "Warm-up Classics" (recommended first), "Advanced Systems" (for more skilled developers), and "Expert Challenges" (for expert developers). Behind the scenes, each problem carries metadata (difficulty, category) that the AI evaluator uses to focus feedback, but this metadata is never shown to the user.

## User Stories

- **US-02.1**: As a user, I can browse system design problems grouped into three experience-level sections so I can pick one appropriate for my current skill level.
- **US-02.2**: As a user, I see only the problem title in the list — no hints or spoilers about what the problem involves.
- **US-02.3**: As a user, I can search problems by title keyword to find specific ones I want to practice.
- **US-02.4**: As a user, I can request the AI to generate new problems for a chosen experience level.
- **US-02.5**: As a user, I can start an interview directly by selecting a problem from the list.
- **US-02.6**: As a user, after completing an interview, I can see the reference solution (if curated) from the evaluation screen — NOT before.

## Acceptance Criteria

- [ ] 20-30 curated problems load from bundled JSON on first launch and seed the database
- [ ] Problem bank screen shows three sections with copywriting:
  - **"Warm-up Classics"** — subtitle: "Recommended first — build foundations with familiar systems"
  - **"Advanced Systems"** — subtitle: "For skilled developers — complex trade-offs and scaling"
  - **"Expert Challenges"** — subtitle: "For expert developers — ambiguous, cutting-edge problems"
- [ ] Each problem in the list shows ONLY the title (no description, no difficulty, no category, no tags)
- [ ] Search field filters problems by title only (not description — which is a spoiler)
- [ ] Selecting a problem starts a new interview session immediately (or goes to Session Setup for timer config)
- [ ] Difficulty and category are stored in the database as metadata but never rendered in the UI
- [ ] AI problem generation accepts experience level ("warm-up" | "advanced" | "expert"), returns problem matching that level
- [ ] Reference solution is only accessible AFTER evaluation completes — shown in Evaluation Result screen (Spec 06), not in Problem Bank
- [ ] All tests pass

## Functional Requirements

- **FR-02.1**: Curated problems are stored in `assets/problems/curated_problems.json` and seeded into the `Problems` table on first launch.
- **FR-02.2**: Each problem record has: id, title, description (the problem statement shown at interview start), difficulty (easy/medium/hard — **metadata only**), category (e.g., storage, messaging, streaming — **metadata only**), tags (JSON array — **metadata only**), reference_solution (nullable markdown), is_curated flag, is_ai_generated flag.
- **FR-02.3**: Experience-level mapping is derived from difficulty:
  - `easy` → "Warm-up Classics"
  - `medium` → "Advanced Systems"
  - `hard` → "Expert Challenges"
- **FR-02.4**: Problem Bank screen renders three section lists, each showing problem titles only, with the section header + subtitle copywriting.
- **FR-02.5**: Problem detail is **not** shown in the Problem Bank. The full description is first revealed when the interview session starts (Spec 03).
- **FR-02.6**: AI problem generation sends a prompt specifying the requested experience level; the AI returns a problem with appropriate difficulty/category metadata.
- **FR-02.7**: Generated problems are stored with `is_ai_generated: true` and assigned to the correct section based on difficulty.
- **FR-02.8**: Reference solutions are accessible ONLY from the Evaluation Result screen (Spec 06), never from Problem Bank or Problem Detail.

## Non-Functional Requirements

- **NFR-02.1**: Problem list renders all 30+ problems without jank (< 16ms frame time).
- **NFR-02.2**: Search results update within 100ms of keystroke (debounced 300ms).
- **NFR-02.3**: Curated JSON seeding completes in < 1 second.

## Edge Cases

- **EC-02.1**: AI provider not configured when user requests AI-generated problem → show message directing to AI Settings.
- **EC-02.2**: AI returns malformed problem JSON → show error, don't save to database.
- **EC-02.3**: Duplicate AI-generated problem (same title as existing) → append "(2)" to title.
- **EC-02.4**: Empty search results → show empty state with "No problems found" message.
- **EC-02.5**: Curated JSON file missing or corrupt → log error, show empty problem bank with explanation.
- **EC-02.6**: A section has zero problems (e.g., user hasn't generated any Expert Challenges yet) → show empty section placeholder: "No {level} problems yet. Generate one with AI or check back later."
