import SwiftUI
import WebKit

struct HTMLMailBodyView: View {
    let html: String
    @State private var allowsRemoteImages = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if containsRemoteImage && !allowsRemoteImages {
                Button {
                    allowsRemoteImages = true
                } label: {
                    Label("外部画像を表示", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Text("画像を表示すると、送信者に開封が伝わる場合があります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            MailWebView(
                html: wrappedHTML,
                allowsRemoteImages: allowsRemoteImages
            )
        }
    }

    private var containsRemoteImage: Bool {
        html.range(
            of: #"<img\b[^>]*\bsrc\s*=\s*["']https?://"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private var wrappedHTML: String {
        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { font: -apple-system-body; color: #111; margin: 0; overflow-wrap: anywhere; }
            img { max-width: 100%; height: auto; }
            @media (prefers-color-scheme: dark) { body { color: #f5f5f5; background: #000; } }
          </style>
        </head>
        <body>\(html)</body>
        </html>
        """
    }
}

private struct MailWebView: UIViewRepresentable {
    let html: String
    let allowsRemoteImages: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(
            html: html,
            allowsRemoteImages: allowsRemoteImages,
            in: webView
        )
    }

    final class Coordinator {
        private var lastSignature: String?

        func load(html: String, allowsRemoteImages: Bool, in webView: WKWebView) {
            let signature = "\(allowsRemoteImages):\(html.hashValue)"
            guard signature != lastSignature else { return }
            lastSignature = signature

            let controller = webView.configuration.userContentController
            controller.removeAllContentRuleLists()

            guard !allowsRemoteImages else {
                webView.loadHTMLString(html, baseURL: nil)
                return
            }

            let rules = """
            [{
              "trigger": {
                "url-filter": "^https?://.*",
                "resource-type": ["image"]
              },
              "action": { "type": "block" }
            }]
            """

            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "MailSwipeBlockRemoteImages",
                encodedContentRuleList: rules
            ) { ruleList, _ in
                DispatchQueue.main.async {
                    if let ruleList {
                        controller.add(ruleList)
                    }
                    webView.loadHTMLString(html, baseURL: nil)
                }
            }
        }
    }
}
