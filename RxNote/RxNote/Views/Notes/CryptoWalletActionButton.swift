//
//  CryptoWalletActionButton.swift
//  RxNote
//
//  Crypto wallet action button with copy-to-clipboard functionality
//

#if os(iOS)
import UIKit
#else
import AppKit
#endif
import RxNoteCore
import SwiftUI

// MARK: - Wallet Network Detection

enum WalletNetwork: String, CaseIterable {
    case ethereum = "Ethereum"
    case bitcoin = "Bitcoin"
    case solana = "Solana"
    case tron = "Tron"
    case litecoin = "Litecoin"
    case dogecoin = "Dogecoin"
    case bitcoinCash = "Bitcoin Cash"
    case ripple = "Ripple"
    case cardano = "Cardano"
    case polkadot = "Polkadot"
    case avalanche = "Avalanche"
    case cosmos = "Cosmos"
    case unknown = "Unknown"

    /// Detects the wallet network based on address format
    static func detect(from address: String) -> WalletNetwork {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ethereum (and EVM-compatible chains): 0x followed by 40 hex characters
        if trimmed.hasPrefix("0x"), trimmed.count == 42,
           trimmed.dropFirst(2).allSatisfy({ $0.isHexDigit }) {
            return .ethereum
        }

        // Bitcoin Legacy (P2PKH): starts with 1, 26-35 characters
        if trimmed.hasPrefix("1"), (26...35).contains(trimmed.count),
           trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return .bitcoin
        }

        // Bitcoin SegWit (P2SH): starts with 3, 26-35 characters
        if trimmed.hasPrefix("3"), (26...35).contains(trimmed.count),
           trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return .bitcoin
        }

        // Bitcoin Native SegWit (Bech32): starts with bc1
        if trimmed.lowercased().hasPrefix("bc1"), (42...62).contains(trimmed.count) {
            return .bitcoin
        }

        // Solana: Base58, 32-44 characters, no 0, O, I, l
        if (32...44).contains(trimmed.count),
           trimmed.allSatisfy({ $0.isLetter || $0.isNumber }),
           !trimmed.contains("0"), !trimmed.contains("O"),
           !trimmed.contains("I"), !trimmed.contains("l") {
            return .solana
        }

        // Tron: starts with T, 34 characters
        if trimmed.hasPrefix("T"), trimmed.count == 34,
           trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return .tron
        }

        // Litecoin Legacy: starts with L or M
        if (trimmed.hasPrefix("L") || trimmed.hasPrefix("M")),
           (26...35).contains(trimmed.count),
           trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return .litecoin
        }

        // Litecoin SegWit: starts with ltc1
        if trimmed.lowercased().hasPrefix("ltc1") {
            return .litecoin
        }

        // Dogecoin: starts with D, 34 characters
        if trimmed.hasPrefix("D"), trimmed.count == 34,
           trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return .dogecoin
        }

        // Bitcoin Cash: starts with bitcoincash: or q/p
        if trimmed.lowercased().hasPrefix("bitcoincash:") ||
           (trimmed.hasPrefix("q") || trimmed.hasPrefix("p")) && trimmed.count == 42 {
            return .bitcoinCash
        }

        // Ripple (XRP): starts with r, 25-35 characters
        if trimmed.hasPrefix("r"), (25...35).contains(trimmed.count),
           trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return .ripple
        }

        // Cardano: starts with addr1
        if trimmed.lowercased().hasPrefix("addr1") {
            return .cardano
        }

        // Polkadot: starts with 1, 47-48 characters (different from Bitcoin by length)
        if trimmed.hasPrefix("1"), (47...48).contains(trimmed.count) {
            return .polkadot
        }

        // Avalanche C-Chain: same as Ethereum (0x prefix)
        // Already covered by Ethereum check above

        // Cosmos: starts with cosmos1
        if trimmed.lowercased().hasPrefix("cosmos1") {
            return .cosmos
        }

        return .unknown
    }
}

// MARK: - Crypto Wallet Action Button

struct CryptoWalletActionButton: View {
    let walletAction: CryptoWalletAction
    @State private var copied = false
    @State private var showingOptions = false

    #if os(iOS)
    @Environment(\.openURL) private var openURL
    #endif

    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack {
                Image(systemName: "wallet.bifold")
                    .font(.body.weight(.medium))
                VStack(alignment: .leading, spacing: 2) {
                    Text(walletAction.label)
                        .font(.body.weight(.medium))
                    HStack(spacing: 4) {
                        Text(walletAction.network)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(truncatedAddress)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if copied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "arrow.up.right.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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
        .foregroundStyle(copied ? .green : Color.appAccent)
        .accessibilityIdentifier("crypto-wallet-button")
        #if os(iOS)
        .confirmationDialog("Wallet Options", isPresented: $showingOptions) {
            if let walletURL = walletDeepLink {
                Button("Open in Wallet App") {
                    openURL(walletURL)
                }
            }
            Button("Copy Address") {
                copyToClipboard()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(walletAction.address)
        }
        #endif
    }

    private var truncatedAddress: String {
        let address = walletAction.address
        if address.count > 16 {
            let prefix = address.prefix(8)
            let suffix = address.suffix(6)
            return "\(prefix)...\(suffix)"
        }
        return address
    }

    private var detectedNetwork: WalletNetwork {
        // Use detected network or try to match from stored network name
        let detected = WalletNetwork.detect(from: walletAction.address)
        if detected != .unknown {
            return detected
        }
        // Try to match stored network name
        return WalletNetwork.allCases.first {
            $0.rawValue.lowercased() == walletAction.network.lowercased()
        } ?? .unknown
    }

    private var walletDeepLink: URL? {
        let address = walletAction.address
        let network = detectedNetwork

        // Generate deep link based on network
        // These are standard URI schemes for crypto payments
        switch network {
        case .ethereum:
            // EIP-681 standard: ethereum:address
            return URL(string: "ethereum:\(address)")
        case .bitcoin:
            // BIP-21 standard: bitcoin:address
            return URL(string: "bitcoin:\(address)")
        case .solana:
            // Solana Pay: solana:address
            return URL(string: "solana:\(address)")
        case .litecoin:
            return URL(string: "litecoin:\(address)")
        case .dogecoin:
            return URL(string: "dogecoin:\(address)")
        case .bitcoinCash:
            return URL(string: "bitcoincash:\(address)")
        case .ripple:
            return URL(string: "ripple:\(address)")
        case .tron:
            return URL(string: "tron:\(address)")
        case .cardano:
            return URL(string: "cardano:\(address)")
        case .cosmos:
            return URL(string: "cosmos:\(address)")
        case .polkadot, .avalanche, .unknown:
            // No standard deep link, return nil
            return nil
        }
    }

    private func handleTap() {
        #if os(iOS)
        // Show options dialog
        showingOptions = true
        #else
        // On macOS, just copy to clipboard
        copyToClipboard()
        #endif
    }

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = walletAction.address
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(walletAction.address, forType: .string)
        #endif

        withAnimation {
            copied = true
        }

        // Reset after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation {
                    copied = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CryptoWalletActionButton(
            walletAction: CryptoWalletAction(
                _type: .crypto_hyphen_wallet,
                label: "My ETH Wallet",
                network: "Ethereum",
                address: "0x1234567890abcdef1234567890abcdef12345678"
            )
        )

        CryptoWalletActionButton(
            walletAction: CryptoWalletAction(
                _type: .crypto_hyphen_wallet,
                label: "BTC Donations",
                network: "Bitcoin",
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
            )
        )

        CryptoWalletActionButton(
            walletAction: CryptoWalletAction(
                _type: .crypto_hyphen_wallet,
                label: "SOL Address",
                network: "Solana",
                address: "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU"
            )
        )
    }
    .padding()
}
