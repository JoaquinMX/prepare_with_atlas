# Spec 04: Whiteboard Integration — plan.md

## Architecture Overview

```mermaid
graph TB
    subgraph Flutter["Flutter Side"]
        WBPanel["WhiteboardPanel (Widget)"]
        WBCtrl["WhiteboardController"]
        WBToolbar["WhiteboardToolbar"]
    end

    subgraph WebView["WebView (WKWebView)"]
        HTML["index.html"]
        Excalidraw["Excalidraw React App"]
        JSAPI["JS Bridge API"]
    end

    subgraph Storage
        DriftDB["WhiteboardSnapshots Table"]
    end

    WBPanel --> WebView
    WBCtrl --> JSAPI
    JSAPI --> Excalidraw
    WBCtrl --> DriftDB

    WBCtrl -.->|"getSceneData()"| JSAPI
    JSAPI -.->|"scene JSON"| WBCtrl
    WBCtrl -.->|"exportToPng()"| JSAPI
    JSAPI -.->|"base64 PNG"| WBCtrl
```

## Communication Protocol

```mermaid
sequenceDiagram
    participant Flutter as WhiteboardController
    participant JS as JS Bridge (WebView)
    participant Excalidraw as Excalidraw

    Note over Flutter,Excalidraw: Initialization
    Flutter->>JS: loadUrl(index.html)
    JS->>Excalidraw: Mount React app
    Excalidraw-->>JS: Ready event
    JS-->>Flutter: postMessage("ready")

    Note over Flutter,Excalidraw: Auto-save (every 30s)
    Flutter->>JS: evaluateJavascript("getSceneData()")
    JS->>Excalidraw: getSceneData()
    Excalidraw-->>JS: scene JSON
    JS-->>Flutter: return JSON string
    Flutter->>Flutter: Save to WhiteboardSnapshots

    Note over Flutter,Excalidraw: Screenshot for evaluation
    Flutter->>JS: evaluateJavascript("exportToPng(1200)")
    JS->>Excalidraw: exportToBlob({maxWidth: 1200})
    Excalidraw-->>JS: Blob → base64
    JS-->>Flutter: return base64 string
    Flutter->>Flutter: Decode to Uint8List
```

## Technology Stack and Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| WebView package | `webview_flutter` (WKWebView on macOS) | Official Flutter team; JS interop support |
| Excalidraw version | Bundled build (not CDN) | Offline support, version control, faster loads |
| Communication | JavaScript channels + evaluateJavascript | Standard WebView interop pattern |
| Fallback | `flutter_inappwebview` if needed | More mature macOS support if issues arise |

## Implementation Sequence

1. Build standalone Excalidraw HTML page with JS bridge API
2. Test HTML page in browser to verify API works
3. Create WhiteboardController with JS interop methods
4. Build WhiteboardPanel widget hosting the WebView
5. Integrate auto-save loop
6. Implement screenshot capture
7. Add WhiteboardToolbar (clear, export)
8. Integrate into InterviewScreen (replace placeholder from Spec 03)

## Constitution Verification

- Excalidraw assets are bundled, not fetched from network → works offline.
- WhiteboardController is the single bridge between Flutter and WebView → all JS calls go through it.
- If WebView package needs swapping, only `WhiteboardPanel` changes — controller interface stays the same.

## Assumptions and Open Questions

- **Assumption**: Excalidraw React app can be built into a single-page bundle for WebView embedding.
- **Assumption**: WKWebView on macOS supports Canvas API (needed for `exportToBlob`).
- **Open**: Should we preinstall Excalidraw libraries via npm build step, or use a prebuilt distribution? Plan assumes prebuilt.
- **RISK**: This is the highest-risk spec. Proof of concept (WebView + JS interop on macOS) should be validated before full implementation.
