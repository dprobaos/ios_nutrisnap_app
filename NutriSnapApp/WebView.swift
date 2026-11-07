//  WebView.swift — WKWebView do NutriSnap "endurecido" para virar app:
//   - JavaScript + localStorage (guarda dieta, refeições, metas, notas)
//   - <input type=file capture> abre a CÂMERA/galeria nativa (foto do prato/dieta)
//   - Diálogos JS (alert/confirm/prompt) via WKUIDelegate (usados pelo app)
//   - Links target="_blank"/window.open abrem na própria WebView
//   - Links externos (outro domínio) abrem no Safari
//   - Ponte Apple Saúde (HealthBridge): peso/gordura da balança → tela Evolução

import SwiftUI
import WebKit

private let SITE_HOST = "probaos.com.br"

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true

        // Sinaliza ao site que está rodando dentro do app (opcional).
        config.userContentController.addUserScript(
            WKUserScript(source: "window.__NATIVE_APP__ = true;",
                         injectionTime: .atDocumentStart, forMainFrameOnly: false))

        config.userContentController.add(context.coordinator.health, name: "health")

        let wv = WKWebView(frame: .zero, configuration: config)
        context.coordinator.health.webView = wv
        wv.allowsBackForwardNavigationGestures = true
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let health = HealthBridge()

        override init() {
            super.init()
            // Voltou ao app (pesou na balança nesse meio-tempo) → relê o Apple Saúde.
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                   object: nil, queue: .main) { [weak self] _ in
                self?.health.sync(pedirPermissao: false)
            }
        }

        // Página carregada → entrega os dados do Apple Saúde (se já conectado).
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            health.sync(pedirPermissao: false)
        }

        // target="_blank"/window.open → carrega na mesma WebView (senão "morre")
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let u = navigationAction.request.url { webView.load(URLRequest(url: u)) }
            return nil
        }

        // Links externos (fora do domínio do site) abrem no Safari.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let u = navigationAction.request.url, let host = u.host,
               !host.contains(SITE_HOST),
               navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(u)
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow)
        }

        // ---------- Diálogos JS ----------
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let ac = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            topVC()?.present(ac, animated: true)
        }
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let ac = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(false) })
            ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
            topVC()?.present(ac, animated: true)
        }
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            let ac = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            ac.addTextField { $0.text = defaultText }
            ac.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(ac.textFields?.first?.text) })
            ac.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completionHandler(nil) })
            topVC()?.present(ac, animated: true)
        }

        private func topVC() -> UIViewController? {
            let root = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
            var top = root
            while let p = top?.presentedViewController { top = p }
            return top
        }
    }
}
