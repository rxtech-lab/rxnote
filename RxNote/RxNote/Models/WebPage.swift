//
//  WebPage.swift
//  RxNote
//
//  Model for web pages displayed in settings
//

import Foundation
import RxNoteCore

/// Represents a web page that can be opened from settings
enum WebPage: Hashable {
    case helpAndSupport
    case privacyPolicy
    case termsOfService

    var title: String {
        switch self {
        case .helpAndSupport: return "Help & Support"
        case .privacyPolicy: return "Privacy Policy"
        case .termsOfService: return "Terms of Service"
        }
    }

    var url: URL {
        let baseURL = AppConfiguration.shared.apiBaseURL
        switch self {
        case .helpAndSupport:
            return URL(string: "\(baseURL)/support")!
        case .privacyPolicy:
            return URL(string: "\(baseURL)/privacy")!
        case .termsOfService:
            return URL(string: "\(baseURL)/terms")!
        }
    }
}
