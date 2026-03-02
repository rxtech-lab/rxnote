//
//  WebPageView.swift
//  RxNote
//
//  Web page view for displaying settings web pages
//

import SwiftUI
import WebKit

/// Displays a web page for settings links (Help & Support, Privacy Policy, Terms of Service)
struct WebPageView: View {
    let page: WebPage

    var body: some View {
        WebViewRepresentable(url: page.url)
            .navigationTitle(page.title)
        #if os(iOS)
            .toolbar(.hidden, for: .tabBar)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - WKWebView Wrapper

#if os(iOS)
    private struct WebViewRepresentable: UIViewRepresentable {
        let url: URL
        @Environment(\.colorScheme) private var colorScheme

        func makeUIView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            let userContentController = WKUserContentController()

            // Inject CSS to support dark mode background
            let darkModeCSS = """
            @media (prefers-color-scheme: dark) {
                html, body {
                    background-color: #000000 !important;
                    color-scheme: dark;
                }
            }
            """
            let cssScript = WKUserScript(
                source:
                "var style = document.createElement('style'); style.innerHTML = '\(darkModeCSS.replacingOccurrences(of: "\n", with: " "))'; document.head.appendChild(style);",
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(cssScript)
            configuration.userContentController = userContentController

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.isOpaque = false
            webView.backgroundColor = .systemBackground
            webView.scrollView.backgroundColor = .systemBackground
            webView.underPageBackgroundColor = .systemBackground
            webView.load(URLRequest(url: url))
            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {}
    }
#else
    private struct WebViewRepresentable: NSViewRepresentable {
        let url: URL

        func makeNSView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            let userContentController = WKUserContentController()

            // Inject CSS to support dark mode background
            let darkModeCSS = """
            @media (prefers-color-scheme: dark) {
                html, body {
                    background-color: #000000 !important;
                    color-scheme: dark;
                }
            }
            """
            let cssScript = WKUserScript(
                source:
                "var style = document.createElement('style'); style.innerHTML = '\(darkModeCSS.replacingOccurrences(of: "\n", with: " "))'; document.head.appendChild(style);",
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(cssScript)
            configuration.userContentController = userContentController

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.setValue(false, forKey: "drawsBackground")
            webView.load(URLRequest(url: url))
            return webView
        }

        func updateNSView(_ webView: WKWebView, context: Context) {}
    }
#endif

#Preview {
    NavigationStack {
        WebPageView(page: .helpAndSupport)
    }
}
