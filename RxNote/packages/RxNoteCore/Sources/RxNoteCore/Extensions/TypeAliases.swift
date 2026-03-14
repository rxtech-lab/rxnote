//
//  TypeAliases.swift
//  RxNoteCore
//
//  Type aliases mapping generated OpenAPI types to simpler names
//

import Foundation

// MARK: - Note Type Aliases

/// A note in the system
public typealias Note = Components.Schemas.NoteResponseSchema

/// Detailed note with whitelist entries
public typealias NoteDetail = Components.Schemas.NoteDetailResponseSchema

/// Create note request
public typealias NoteInsert = Components.Schemas.NoteInsertSchema

/// Update note request
public typealias NoteUpdate = Components.Schemas.NoteUpdateSchema

/// Paginated notes response
public typealias PaginatedNotesResponse = Components.Schemas.PaginatedNotesResponse

// MARK: - Note Actions

/// URL action
public typealias URLAction = Components.Schemas.URLActionSchema

/// WiFi action
public typealias WifiAction = Components.Schemas.WifiActionSchema

/// Add contact action
public typealias AddContactAction = Components.Schemas.AddContactActionSchema

/// Crypto wallet action
public typealias CryptoWalletAction = Components.Schemas.CryptoWalletActionSchema

/// Action (discriminated union)
public typealias NoteAction = Components.Schemas.ActionSchema

/// Business card data for business-card note type
public typealias BusinessCard = Components.Schemas.BusinessCardSchema

/// Typed value entry (e.g., email/phone with type label)
public typealias TypedValue = Components.Schemas.TypedValueSchema

/// Name-value entry (e.g., social profile with platform name)
public typealias NameValue = Components.Schemas.NameValueSchema

/// Structured address
public typealias BusinessCardAddress = Components.Schemas.AddressSchema

/// Business card presets response
public typealias BusinessCardPresets = Components.Schemas.BusinessCardPresetsResponseSchema

// MARK: - Whitelist Type Aliases

/// Whitelist entry response
public typealias NoteWhitelist = Components.Schemas.NoteWhitelistResponseSchema

/// Request to add to whitelist
public typealias NoteWhitelistAddRequest = Components.Schemas.NoteWhitelistAddRequestSchema

/// Request to remove from whitelist
public typealias NoteWhitelistRemoveRequest = Components.Schemas.NoteWhitelistRemoveRequestSchema

// MARK: - QR Code Type Aliases

/// QR code scan response
public typealias QrCodeScanResponse = Components.Schemas.QrCodeScanResponseSchema

/// QR code scan request
public typealias QrCodeScanRequest = Components.Schemas.QrCodeScanRequestSchema

/// QR code type enum
public typealias QrCodeType = Components.Schemas.QrCodeTypeSchema

// MARK: - Upload Type Aliases

/// Presigned upload response
public typealias PresignedUploadResponse = Components.Schemas.PresignedUploadResponseSchema

/// Request for presigned upload URL
public typealias PresignedUploadRequest = Components.Schemas.PresignedUploadRequestSchema

// MARK: - Account Deletion Type Aliases

/// Account deletion status response
public typealias AccountDeletionStatus = Components.Schemas.AccountDeletionStatusResponseSchema

/// Account deletion request response
public typealias AccountDeletionRequestResponse = Components.Schemas.AccountDeletionRequestResponseSchema

/// Account deletion cancel response
public typealias AccountDeletionCancelResponse = Components.Schemas.AccountDeletionCancelResponseSchema

/// Account deletion record
public typealias AccountDeletion = Components.Schemas.AccountDeletionResponseSchema

// MARK: - Common Type Aliases

/// Pagination info
public typealias PaginationInfo = Components.Schemas.PaginationInfo

/// Signed image with id and URL
public typealias SignedImage = Components.Schemas.SignedImageSchema
