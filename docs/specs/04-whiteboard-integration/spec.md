# Spec 04: Whiteboard Integration — spec.md

## Summary

An embedded interactive whiteboard for drawing system architecture diagrams during mock interviews. Uses Excalidraw loaded in a WebView with bidirectional JavaScript communication for saving/restoring state and capturing screenshots for AI evaluation.

## User Stories

- **US-04.1**: As a user, I can draw architecture diagrams (boxes, arrows, text, freehand) on a whiteboard panel during my interview.
- **US-04.2**: As a user, my whiteboard state is preserved when I switch between stages.
- **US-04.3**: As a user, I can clear the whiteboard to start fresh.
- **US-04.4**: As a user, my whiteboard is automatically captured as an image when I end my session for AI evaluation.
- **US-04.5**: As a user, I can review my whiteboard drawing from a past session.

## Acceptance Criteria

- [ ] Excalidraw loads within a WebView panel in the interview workspace
- [ ] Drawing tools work: freehand pen, rectangles, ellipses, arrows, text, line
- [ ] Whiteboard state (Excalidraw JSON scene) auto-saves every 30 seconds
- [ ] Whiteboard state persists across stage transitions within the same session
- [ ] "Clear" button resets the canvas with confirmation dialog
- [ ] Screenshot capture returns a PNG image (≤1200px width) suitable for AI multimodal input
- [ ] Past session whiteboard can be restored in read-only mode
- [ ] WebView loads in < 3 seconds on first render
- [ ] All tests pass

## Functional Requirements

- **FR-04.1**: Bundle a self-contained HTML file (`assets/excalidraw/index.html`) that loads Excalidraw from local JS assets (no CDN dependency).
- **FR-04.2**: JavaScript API exposed to Flutter via message channels: `getSceneData()`, `loadSceneData(json)`, `exportToPng(maxWidth)`, `clearCanvas()`.
- **FR-04.3**: `WhiteboardController` manages: WebView initialization, periodic auto-save (30s), screenshot capture on session end.
- **FR-04.4**: Whiteboard scene JSON is stored in the `WhiteboardSnapshots` table; screenshot PNG in the `screenshot_png` blob column.
- **FR-04.5**: In review mode, Excalidraw loads with `viewModeEnabled: true` (read-only).

## Non-Functional Requirements

- **NFR-04.1**: WebView initial load < 3 seconds.
- **NFR-04.2**: JS interop round-trip (getSceneData → Flutter) < 100ms.
- **NFR-04.3**: Screenshot export < 2 seconds for complex diagrams.
- **NFR-04.4**: Bundled Excalidraw JS assets < 5MB total.

## Edge Cases

- **EC-04.1**: WebView fails to load → show error overlay with "Retry" button and fallback text: "Whiteboard unavailable. You can continue with notes only."
- **EC-04.2**: JS interop call times out (> 5s) → retry once, then save session without whiteboard data.
- **EC-04.3**: Very complex drawing (1000+ elements) → may slow export; show progress indicator during PNG capture.
- **EC-04.4**: App resized while WebView is active → Excalidraw handles responsive resize natively.
- **EC-04.5**: Scene JSON exceeds 1MB → warn but still save (unlikely in practice).
- **EC-04.6**: `setProblemStatement` JS call fails (e.g. WebView HTML not yet updated to expose the function) → swallow silently and log via `dart:developer`; the problem-title banner is non-critical and session continues normally.
- **EC-04.7**: Auto-save closure must not capture `ref` — the timer callback may fire after the widget unmounts. The whiteboard repository reference is captured once at auto-save start time and reused inside the closure.
