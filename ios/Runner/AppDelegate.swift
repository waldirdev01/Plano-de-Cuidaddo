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
    let pdfChannel = FlutterMethodChannel(name: "br.com.waldirdev01.plano_cuidado/pdf", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    pdfChannel.setMethodCallHandler { call, result in
      guard call.method == "extrair" else { result(FlutterMethodNotImplemented); return }
      guard let args = call.arguments as? [String: Any],
            let bytes = args["bytes"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "pdf_invalido", message: "Selecione um PDF válido.", details: nil)); return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let extracted = try LeitorPdfNativo.extrair(bytes.data)
          DispatchQueue.main.async { result(extracted) }
        } catch {
          // Do not include document contents or patient information in diagnostics.
          let message = error.localizedDescription
          DispatchQueue.main.async {
            result(FlutterError(code: "pdf_invalido", message: message, details: nil))
          }
        }
      }
    }
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
