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
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - WKWebView Wrapper

#if os(iOS)
    private struct WebViewRepresentable: UIViewRepresentable {
        let url: URL

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.load(URLRequest(url: url))
            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {}
    }
#else
    private struct WebViewRepresentable: NSViewRepresentable {
        let url: URL

        func makeNSView(context: Context) -> WKWebView {
            let webView = WKWebView()
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
