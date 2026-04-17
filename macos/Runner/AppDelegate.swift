import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(
    _ app: NSApplication
  ) -> Bool {
    return true
  }

  /// Handles custom URI scheme callbacks for OpenAI OAuth 2.1/PKCE.
  ///
  /// When the system browser redirects to
  /// `com.joaquinmx.preparewithatlas://oauth/callback?code=…`, macOS
  /// delivers the URL here. We forward the full URL string to Flutter via
  /// the `com.joaquinmx.preparewithatlas/oauth` method channel so that
  /// `OpenAiOAuthService` can extract the authorization code.
  override func application(
    _ application: NSApplication,
    open urls: [URL]
  ) {
    guard
      let url = urls.first,
      url.scheme == "com.joaquinmx.preparewithatlas",
      let controller = NSApplication.shared.windows.first?
        .contentViewController as? FlutterViewController
    else { return }

    let channel = FlutterMethodChannel(
      name: "com.joaquinmx.preparewithatlas/oauth",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.invokeMethod("onCallback", arguments: url.absoluteString)
  }
}
