import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, FlutterStreamHandler {
  private var incomingSink: FlutterEventSink?
  private var pendingIncoming: String?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterEventChannel(name: "br.com.waldirdev01.plano_cuidado/incoming-files", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    incomingSink = events
    if let path = pendingIncoming { events(path); pendingIncoming = nil }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? { incomingSink = nil; return nil }

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    forwardIncomingURL(url)
    return true
  }

  func forwardIncomingURL(_ url: URL) {
    let hasAccess = url.startAccessingSecurityScopedResource()
    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
    do {
      let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let folder = root.appendingPathComponent("planos_recebidos", isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let destination = folder.appendingPathComponent("recebido-\(UUID().uuidString).plano")
      try FileManager.default.copyItem(at: url, to: destination)
      let path = destination.path
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        if let sink = self.incomingSink { sink(path) } else { self.pendingIncoming = path }
      }
    } catch { NSLog("Falha ao receber arquivo de plano: %@", error.localizedDescription) }
  }
}
