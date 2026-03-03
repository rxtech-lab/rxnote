//
//  PresetService.swift
//  RxNoteCore
//
//  Preset service for fetching business card field presets
//

import Foundation
import Logging
import OpenAPIRuntime

private let logger = Logger(label: "PresetService")

public struct PresetService: Sendable {
    public init() {}

    @APICall(.ok)
    public func getBusinessCardPresets() async throws -> BusinessCardPresets {
        try await StorageAPIClient.shared.optionalAuthClient.getBusinessCardPresets(.init())
    }
}
