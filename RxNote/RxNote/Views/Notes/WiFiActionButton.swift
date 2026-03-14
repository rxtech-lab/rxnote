//
//  WiFiActionButton.swift
//  RxNote
//
//  WiFi action button with auto-connect functionality
//

#if os(iOS)
import NetworkExtension
#endif
import RxNoteCore
import SwiftUI

// MARK: - WiFi Connection State

enum WiFiConnectionState: Equatable {
    case idle
    case connecting(ssid: String)
    case connected(ssid: String)
    case failed(ssid: String, message: String)

    func isConnecting(ssid: String) -> Bool {
        if case .connecting(let connectingSSID) = self {
            return connectingSSID == ssid
        }
        return false
    }
}

// MARK: - WiFi Action Button

struct WiFiActionButton: View {
    let wifiAction: WifiAction
    @Binding var connectionState: WiFiConnectionState

    var body: some View {
        Button {
            Task { await connectToWiFi() }
        } label: {
            HStack {
                statusIcon
                    .font(.body.weight(.medium))
                VStack(alignment: .leading, spacing: 2) {
                    Text(wifiAction.ssid)
                        .font(.body.weight(.medium))
                    statusText
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailingIcon
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            #if os(iOS)
            .background(Color(.secondarySystemBackground))
            #else
            .background(Color(NSColor.controlBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .foregroundStyle(titleColor)
        .disabled(isConnecting)
    }

    private var isConnecting: Bool {
        connectionState.isConnecting(ssid: wifiAction.ssid)
    }
    
    private var isConnected: Bool {
        if case .connected(let connectedSSID) = connectionState {
            return connectedSSID == wifiAction.ssid
        }
        return false
    }
    
    private var titleColor: Color {
        if isConnecting {
            return .secondary
        } else if isConnected {
            return .green
        } else {
            return Color.appAccent
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch connectionState {
        case .connecting(let connectingSSID) where connectingSSID == wifiAction.ssid:
            ProgressView()
                .controlSize(.small)
        case .connected(let connectedSSID) where connectedSSID == wifiAction.ssid:
            Image(systemName: "wifi")
                .foregroundStyle(.green)
        case .failed(let failedSSID, _) where failedSSID == wifiAction.ssid:
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.red)
        default:
            Image(systemName: "wifi")
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch connectionState {
        case .connecting(let connectingSSID) where connectingSSID == wifiAction.ssid:
            Text("Connecting...")
        case .connected(let connectedSSID) where connectedSSID == wifiAction.ssid:
            Text("Connected")
                .foregroundStyle(.green)
        case .failed(let failedSSID, let message) where failedSSID == wifiAction.ssid:
            Text(message)
                .foregroundStyle(.red)
        default:
            Text("Tap to connect")
        }
    }

    @ViewBuilder
    private var trailingIcon: some View {
        switch connectionState {
        case .connected(let connectedSSID) where connectedSSID == wifiAction.ssid:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let failedSSID, _) where failedSSID == wifiAction.ssid:
            Image(systemName: "arrow.clockwise")
        default:
            Image(systemName: "arrow.right.circle")
        }
    }

    private func connectToWiFi() async {
        #if os(iOS)
        let ssid = wifiAction.ssid
        connectionState = .connecting(ssid: ssid)

        let configuration: NEHotspotConfiguration
        if let password = wifiAction.password, !password.isEmpty {
            let isWEP = wifiAction.encryption?.rawValue.uppercased() == "WEP"
            configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: isWEP)
        } else {
            configuration = NEHotspotConfiguration(ssid: ssid)
        }
        configuration.joinOnce = true

        do {
            // Use a longer timeout (30 seconds) for WiFi connection attempts
            // This accounts for user interaction time and network discovery
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await NEHotspotConfigurationManager.shared.apply(configuration)
                }
                
                group.addTask {
                    try await Task.sleep(for: .seconds(30))
                    throw WiFiConnectionError.timeout
                }
                
                // Wait for the first task to complete (either connection or timeout)
                try await group.next()
                group.cancelAll()
            }
            
            // Check if we actually connected to the network
            if let currentNetwork = await NEHotspotNetwork.fetchCurrent(),
               currentNetwork.ssid == ssid {
                connectionState = .connected(ssid: ssid)
            } else {
                // User may have denied or network not found
                connectionState = .failed(ssid: ssid, message: "Connection cancelled")
            }
        } catch WiFiConnectionError.timeout {
            connectionState = .failed(ssid: ssid, message: "Connection timed out")
        } catch {
            handleConnectionError(error, ssid: ssid)
        }
        #else
        // WiFi auto-connect is not available on macOS
        connectionState = .failed(ssid: wifiAction.ssid, message: "Not available on macOS")
        #endif
    }
    
    #if os(iOS)
    private enum WiFiConnectionError: Error {
        case timeout
    }
    #endif

    #if os(iOS)
    private func handleConnectionError(_ error: Error, ssid: String) {
        let nsError = error as NSError
        if nsError.domain == NEHotspotConfigurationErrorDomain {
            switch nsError.code {
            case NEHotspotConfigurationError.alreadyAssociated.rawValue:
                connectionState = .connected(ssid: ssid)
            case NEHotspotConfigurationError.userDenied.rawValue:
                connectionState = .failed(ssid: ssid, message: "Connection cancelled")
            case NEHotspotConfigurationError.invalid.rawValue,
                 NEHotspotConfigurationError.invalidSSID.rawValue,
                 NEHotspotConfigurationError.invalidSSIDPrefix.rawValue:
                connectionState = .failed(ssid: ssid, message: "Invalid network")
            case NEHotspotConfigurationError.invalidWPAPassphrase.rawValue,
                 NEHotspotConfigurationError.invalidWEPPassphrase.rawValue:
                connectionState = .failed(ssid: ssid, message: "Invalid password")
            default:
                connectionState = .failed(ssid: ssid, message: "Connection failed")
            }
        } else {
            connectionState = .failed(ssid: ssid, message: "Connection failed")
        }
    }
    #endif
}

#Preview {
    VStack(spacing: 16) {
        WiFiActionButton(
            wifiAction: WifiAction(
                _type: .wifi,
                ssid: "GuestNetwork",
                password: "welcome123",
                encryption: .WPA
            ),
            connectionState: .constant(.idle)
        )

        WiFiActionButton(
            wifiAction: WifiAction(
                _type: .wifi,
                ssid: "ConnectingNetwork",
                password: nil,
                encryption: nil
            ),
            connectionState: .constant(.connecting(ssid: "ConnectingNetwork"))
        )

        WiFiActionButton(
            wifiAction: WifiAction(
                _type: .wifi,
                ssid: "ConnectedNetwork",
                password: nil,
                encryption: nil
            ),
            connectionState: .constant(.connected(ssid: "ConnectedNetwork"))
        )
    }
    .padding()
}
