import SwiftUI
import WebKit
import UIKit
import UniformTypeIdentifiers

/// Hosts the dashboard. One `index.html` from the app bundle, loaded off disk, so the app opens
/// on a plane, in a tunnel and on a dead phone signal exactly as it does anywhere else — there is
/// no remote page to fail to arrive, and no white screen where one would have been.
struct WebHost: UIViewControllerRepresentable {
    @EnvironmentObject private var lock: AppLock
    @Binding var pendingAction: String?

    func makeUIViewController(context: Context) -> WebHostController {
        let vc = WebHostController()
        vc.lock = lock
        return vc
    }

    func updateUIViewController(_ vc: WebHostController, context: Context) {
        vc.lock = lock
        if let action = pendingAction {
            vc.deliver(action: action)
            // Cleared on the next runloop turn: writing to @Binding inside updateUIViewController
            // re-enters SwiftUI's update, which it rightly complains about.
            DispatchQueue.main.async { pendingAction = nil }
        }
    }
}

final class WebHostController: UIViewController {

    private(set) var webView: WKWebView!
    weak var lock: AppLock?
    private var isReady = false
    private var queuedAction: String?

    override func loadView() {
        let content = WKUserContentController()
        content.add(Bridge(host: self), name: NativeBridge.name)
        content.addUserScript(WKUserScript(source: NativeBridge.script,
                                           injectionTime: .atDocumentStart,
                                           forMainFrameOnly: true))

        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.websiteDataStore = .default()      // the app's own container; nothing sweeps it
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 10 / 255, green: 11 / 255, blue: 14 / 255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.bounces = false        // the dashboard manages its own scrolling
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // A finance dashboard is not a document; pinch-zooming it only ever produces a mess.
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.minimumZoomScale = 1

        self.webView = webView
        self.view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else {
            assertionFailure("index.html is missing from the bundle — check Copy Bundle Resources.")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())

        // Dynamic Type. A web view ignores the system text size, which is how a great many
        // wrapped apps end up unusable for anyone who has turned it up — and it is one of the
        // things the App Store now treats as a quality failure rather than a preference.
        _ = registerForTraitChanges([UITraitPreferredContentSizeCategory.self],
                                    action: #selector(applyTextScale))
        applyTextScale()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyTextScale()          // the cap depends on the width, so it is recomputed on rotation
    }

    /// The system text size, translated into page zoom — bounded so the dashboard is never asked
    /// to lay itself out narrower than the 320pt it is designed and tested down to. Enlarging past
    /// that point does not help somebody read: it produces a column of overlapping figures, which
    /// is the failure mode this is meant to avoid rather than cause.
    @objc private func applyTextScale() {
        let wanted: CGFloat
        switch traitCollection.preferredContentSizeCategory {
        case .extraSmall:                             wanted = 0.88
        case .small:                                  wanted = 0.92
        case .medium:                                 wanted = 0.96
        case .large:                                  wanted = 1.00     // the default
        case .extraLarge:                             wanted = 1.08
        case .extraExtraLarge:                        wanted = 1.16
        case .extraExtraExtraLarge:                   wanted = 1.24
        case .accessibilityMedium:                    wanted = 1.34
        case .accessibilityLarge:                     wanted = 1.44
        case .accessibilityExtraLarge,
             .accessibilityExtraExtraLarge,
             .accessibilityExtraExtraExtraLarge:      wanted = 1.55
        default:                                      wanted = 1.00
        }
        let width = view.bounds.width
        let cap = width > 0 ? max(1.0, width / 320) : 1.0
        let zoom = min(wanted, cap)
        if abs(webView.pageZoom - zoom) > 0.001 { webView.pageZoom = zoom }
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: NativeBridge.name)
    }

    // MARK: talking to the page

    /// Quick actions arrive before the dashboard has finished starting far more often than not,
    /// because the tap that launched the app is what sent them. Held until it says it is ready.
    func deliver(action: String) {
        guard isReady else { queuedAction = action; return }
        let json = String(data: (try? JSONEncoder().encode(action)) ?? Data(), encoding: .utf8) ?? "\"\""
        webView.evaluateJavaScript("window.__finsightNative && window.__finsightNative.action(\(json));")
    }

    func webAppBecameReady() {
        guard !isReady else { return }
        isReady = true
        if let queued = queuedAction { queuedAction = nil; deliver(action: queued) }
        // Tell the page what this device can actually do, so its Settings screen can offer the
        // app lock only where there is something to offer.
        let canLock = AppLock.biometryAvailable
        let name = AppLock.biometryName.replacingOccurrences(of: "\"", with: "")
        let on = lock?.isEnabled ?? false
        webView.evaluateJavaScript("""
        window.__finsightNative && window.__finsightNative.capabilities(\
        {"lock":\(canLock),"lockName":"\(name)","lockOn":\(on)});
        """)
    }
}

// MARK: - Navigation

extension WebHostController: WKNavigationDelegate {

    /// The only page this app should ever be on is its own. A tapped link to the web opens in
    /// Safari; a remote address the page navigated to itself is refused, because the only way
    /// that happens is something having gone wrong — and a remote page wearing the app's chrome,
    /// with no address bar to contradict it, is a good place to ask somebody for a PIN.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
            decisionHandler(.cancel); return
        }
        if scheme == "http" || scheme == "https" {
            if navigationAction.navigationType == .linkActivated { UIApplication.shared.open(url) }
            decisionHandler(.cancel); return
        }
        decisionHandler(scheme == "file" || scheme == "about" ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // The page posts `ready` itself once React has mounted; this is the backstop for a build
        // where it does not, so a quick action is never swallowed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.webAppBecameReady()
        }
    }
}

extension WebHostController: WKUIDelegate {

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
            UIApplication.shared.open(url)
        }
        return nil
    }

    // WKWebView does nothing with alert/confirm/prompt unless the host draws them, and the
    // dashboard uses all three — setting a value, confirming a delete, warning about an import.

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: "FinSight", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: "FinSight", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: "FinSight", message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText; $0.clearButtonMode = .whileEditing }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { [weak a] _ in
            completionHandler(a?.textFields?.first?.text ?? "")
        })
        present(a, animated: true)
    }
}

// MARK: - Export (share sheet) and import (Files)

extension WebHostController {

    func export(data: Data, suggestedName: String) {
        // The name comes from the web layer, so it is not ours to trust: "../../Library/x.plist"
        // would append cleanly and write outside the temporary directory.
        let leaf = (suggestedName as NSString).lastPathComponent
        let safe = leaf.isEmpty || leaf == "." || leaf == ".." ? "finsight-export" : leaf
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safe)
        do { try data.write(to: url, options: .atomic) } catch {
            return present(message: "Couldn't prepare \(safe) for export.")
        }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(share, animated: true)
    }

    /// Restore a backup straight from Files or iCloud Drive, which a web page in a browser
    /// cannot reach. Reads the file here and hands the text to the page's own restore path, so
    /// the same validation applies however the file arrived.
    func importBackup() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func present(message: String) {
        let a = UIAlertController(title: "FinSight", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

extension WebHostController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        // asCopy: true hands us a copy in our own container, so no security-scoped dance.
        guard let data = try? Data(contentsOf: url), data.count <= 32 * 1024 * 1024,
              let text = String(data: data, encoding: .utf8) else {
            return present(message: "That file couldn't be read as a FinSight backup.")
        }
        let json = String(data: (try? JSONEncoder().encode(text)) ?? Data(), encoding: .utf8) ?? "\"\""
        webView.evaluateJavaScript("window.__finsightNative && window.__finsightNative.restore(\(json));")
    }
}

// MARK: - Bridge plumbing

/// Split out so the controller is not itself the message handler: `WKUserContentController`
/// retains its handlers, and a controller retaining a content controller that retains the
/// controller never goes away.
private final class Bridge: NSObject, WKScriptMessageHandler {
    weak var host: WebHostController?
    init(host: WebHostController) { self.host = host }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == NativeBridge.name,
              let body = message.body as? [String: Any],
              let action = body["action"] as? String,
              let host else { return }
        // These already arrive on the main thread; the hop is what tells the compiler so, since
        // the handler protocol carries no isolation of its own.
        Task { @MainActor in NativeBridge.handle(action: action, body: body, host: host) }
    }
}
