# Spec 02: Problem Bank — tasks.md

## Phase 1: Domain Model (TDD)

- **T001**: Write tests for `ExperienceLevel` enum — verify: 3 values (warmUp, advanced, expert), fromDifficulty mapper (easy→warmUp, medium→advanced, hard→expert), displayLabel and subtitle copywriting constants.
- **T002**: Implement `ExperienceLevel` enum with `fromDifficulty()` mapper and display strings matching the copywriting spec.
- **T003**: Write tests for `Problem` freezed model — verify: creation with all fields, copyWith, JSON serialization/deserialization, equality.
- **T004**: Implement `Problem` freezed model in `features/problem_bank/domain/problem.dart`.
- **T005**: Define `ProblemRepository` abstract class with methods: `getBySection(ExperienceLevel)`, `getById(id)`, `searchByTitle(query)`, `insert(problem)`, `delete(id)`, `watchAll()`.

## Phase 2: Data Layer (TDD)

- **T006**: Write tests for `DriftProblemRepository` — verify: insert + getBySection round-trip, getBySection(warmUp) returns only easy, searchByTitle is case-insensitive and matches title only (not description), delete.
- **T007**: Implement `DriftProblemRepository` using the existing `Problems` table from AppDatabase.
- **T008**: Create `assets/problems/curated_problems.json` with 5 seed problems (2 warm-up, 2 advanced, 1 expert — expand to 20-30 before release).
- **T009**: Write tests for `CuratedProblemsLoader` — verify: loads JSON, parses all problems, inserts into repository, skips seeding if already seeded (idempotent).
- **T010**: Implement `CuratedProblemsLoader` that reads the asset JSON and seeds the database on first launch.

## Phase 3: Application Layer (TDD)

- **T011**: Write tests for `ProblemBankController` — verify: initializes with 3 sections populated from repository, search filters each section by title only, clearing search restores all.
- **T012**: Implement `ProblemBankController` (StateNotifier) with state: `Map<ExperienceLevel, List<Problem>>` sections, search query, loading flag.
- **T013**: Add Riverpod providers for `ProblemRepository` and `ProblemBankController` to `shared/providers.dart`.

## Phase 4: Presentation (TDD) — No-Spoilers Enforcement

- **T014**: Write widget tests for `ProblemBankScreen` — verify: renders three section headers with exact copywriting ("Warm-up Classics", "Advanced Systems", "Expert Challenges"), each section shows a list of ProblemTile widgets, search field filters sections in real-time, tapping a problem tile navigates to session setup.
- **T015**: Write widget test for `ProblemTile` — verify: shows ONLY the title, does NOT render difficulty/category/description/tags anywhere, tile is tappable.
- **T016**: Implement `ProblemTile` widget — minimal card with title only, accent hover state. Add a TODO comment with `@visibleForTesting` asserting no metadata fields are referenced.
- **T017**: Implement `ProblemBankScreen` with three `SectionView` widgets, each with header, subtitle, and list of ProblemTiles.
- **T018**: Write widget test for empty section state — verify: section with zero problems shows "No {level} problems yet" placeholder.
- **T019**: Implement empty section placeholder.

## Phase 5: AI Generation (deferred until Spec 05 is complete)

- **T020**: Write tests for AI problem generation — verify: prompt includes requested experience level, parsed response is stored with correct difficulty mapping, malformed response returns error.
- **T021**: Implement AI problem generation in `ProblemBankController` using `AIProvider` from Spec 05.
- **T022**: Add "Generate Problem" FAB to `ProblemBankScreen` with experience-level picker dialog (warm-up / advanced / expert).
