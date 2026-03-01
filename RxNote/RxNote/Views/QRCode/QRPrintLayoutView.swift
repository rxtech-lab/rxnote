//
//  QRPrintLayoutView.swift
//  RxNote
//
//  Pure SwiftUI layout view for QR code print rendering
//

import RxNoteCore
import SwiftUI

#if os(iOS)

    /// Print layout view that renders a QR code with note metadata.
    /// Uses white background and black text for clean printing.
    struct QRPrintLayoutView: View {
        let noteTitle: String
        let noteContent: String?
        let qrImage: UIImage
        let configuration: QRPrintConfiguration

        private var pageWidth: CGFloat {
            configuration.pageSize.width
        }

        private var pageHeight: CGFloat {
            configuration.pageSize.height
        }

        private var qrSize: CGFloat {
            configuration.qrCodeSize
        }

        private var padding: CGFloat {
            configuration.padding
        }

        var body: some View {
            Group {
                if configuration.qrCodePosition.isHorizontal {
                    horizontalLayout
                } else {
                    verticalLayout
                }
            }
            .padding(padding)
            .frame(
                width: pageWidth,
                height: pageHeight,
                alignment: Alignment(
                    horizontal: .center,
                    vertical: configuration.verticalAlignment.verticalAlignment
                )
            )
            .background(Color.white)
        }

        // MARK: - Vertical Layout (Top / Bottom)

        private var verticalLayout: some View {
            VStack(spacing: 0) {
                if configuration.qrCodePosition == .top {
                    qrCodeSection
                    Spacer().frame(height: configuration.verticalSpacing)
                    metadataSection
                } else {
                    metadataSection
                    Spacer().frame(height: configuration.verticalSpacing)
                    qrCodeSection
                }
            }
        }

        // MARK: - Horizontal Layout (Left / Right)

        private var horizontalLayout: some View {
            HStack(alignment: .center, spacing: configuration.horizontalSpacing) {
                if configuration.qrCodePosition == .left {
                    qrCodeView
                    horizontalMetadataSection
                } else {
                    horizontalMetadataSection
                    qrCodeView
                }
            }
            .frame(maxWidth: .infinity, alignment: alignmentAnchor)
        }

        // MARK: - QR Code Section

        private var qrCodeView: some View {
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: qrSize, height: qrSize)
        }

        private var qrCodeSection: some View {
            qrCodeView
                .frame(maxWidth: .infinity, alignment: alignmentAnchor)
        }

        // MARK: - Metadata Section

        private var metadataSection: some View {
            metadataContent
                .frame(maxWidth: .infinity, alignment: alignmentAnchor)
        }

        private var horizontalMetadataSection: some View {
            VStack(alignment: configuration.qrCodePosition == .left ? .leading : .trailing, spacing: configuration.verticalSpacing) {
                ForEach(configuration.activeFields) { field in
                    fieldView(for: field)
                }
            }
        }

        private var metadataContent: some View {
            VStack(alignment: configuration.alignment.horizontalAlignment, spacing: configuration.verticalSpacing) {
                ForEach(configuration.activeFields) { field in
                    fieldView(for: field)
                }
            }
        }

        // MARK: - Field Rendering

        @ViewBuilder
        private func fieldView(for field: QRPrintField) -> some View {
            let value = configuration.fieldValue(for: field, title: noteTitle, note: noteContent)

            switch field {
            case .title:
                Text(value ?? "Untitled")
                    .font(configuration.titleFont)
                    .foregroundColor(.black)
                    .multilineTextAlignment(configuration.alignment.textAlignment)

            case .note:
                if let value {
                    Text(value)
                        .font(configuration.bodyFont)
                        .foregroundColor(.black)
                        .multilineTextAlignment(configuration.alignment.textAlignment)
                }
            }
        }

        private var alignmentAnchor: Alignment {
            switch configuration.alignment {
            case .leading: .leading
            case .center: .center
            case .trailing: .trailing
            }
        }
    }

#endif
