# Spec 04: Whiteboard Integration — tasks.md

## Phase 1: Excalidraw HTML Bundle

- **T001**: Create `assets/excalidraw/index.html` — minimal HTML page that loads Excalidraw React app from bundled JS.
- **T002**: Implement JS bridge API in index.html: `window.getSceneData()`, `window.loadSceneData(json)`, `window.exportToPng(maxWidth)`, `window.clearCanvas()`, `window.setViewMode(bool)`.
- **T003**: Add `postMessage("ready")` call when Excalidraw mount completes.
- **T004**: Test HTML page in a standalone browser — verify all JS API functions work correctly.

## Phase 2: WhiteboardController (TDD)

- **T005**: Write tests for `WhiteboardController` — verify: `initialize()` sets up WebView, `getSceneData()` returns JSON string, `loadSceneData()` sends JSON to WebView, `captureScreenshot()` returns Uint8List, `clearCanvas()` resets state.
- **T006**: Implement `WhiteboardController` (StateNotifier) with JS interop methods using `WebViewController.runJavaScript()` and `JavaScriptChannel`.
- **T007**: Write tests for auto-save logic — verify: saves scene every 30 seconds, saves on session end.
- **T008**: Implement auto-save timer in WhiteboardController (30-second periodic save to `WhiteboardSnapshots` table).

## Phase 3: Presentation (TDD)

- **T009**: Write widget tests for `WhiteboardPanel` — verify: WebView widget renders, loading overlay shows until "ready" message received, error overlay shows on load failure.
- **T010**: Implement `WhiteboardPanel` widget — hosts WebView, shows loading skeleton, handles errors.
- **T011**: Write widget tests for `WhiteboardToolbar` — verify: "Clear" button shows confirmation dialog, "Export" button triggers screenshot.
- **T012**: Implement `WhiteboardToolbar` with clear (with confirmation) and export buttons.

## Phase 4: Integration

- **T013**: Replace whiteboard placeholder in `InterviewScreen` (Spec 03) with `WhiteboardPanel`.
- **T014**: Wire `WhiteboardController` into `SessionController` — capture screenshot on session end.
- **T015**: Implement read-only mode for session review — load scene data with `setViewMode(true)`.
- **T016**: End-to-end test: draw on whiteboard → save session → verify scene JSON and screenshot PNG stored in database → load in review mode → verify drawing restored.
