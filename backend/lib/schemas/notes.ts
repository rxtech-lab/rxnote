import { z } from "zod";
import { PaginationInfo, PaginationQueryParams } from "./common";

// Shared schemas
export const TypedValueSchema = z.object({
  type: z.string().min(1).describe("Type label (e.g., Work, Personal, Mobile)"),
  value: z.string().min(1).describe("The value"),
});

export const NameValueSchema = z.object({
  name: z.string().min(1).describe("Platform or service name"),
  value: z.string().min(1).describe("Username or handle"),
});

export const AddressSchema = z.object({
  street: z.string().optional().describe("Street address"),
  city: z.string().optional().describe("City"),
  state: z.string().optional().describe("State or province"),
  zip: z.string().optional().describe("Zip or postal code"),
  country: z.string().optional().describe("Country"),
});

// Action schemas
export const URLActionSchema = z.object({
  type: z.literal("url"),
  label: z.string().describe("Display label for the URL action"),
  url: z.string().url().describe("URL to open"),
});

export const WifiActionSchema = z.object({
  type: z.literal("wifi"),
  ssid: z.string().describe("WiFi network name"),
  password: z.string().optional().describe("WiFi password"),
  encryption: z
    .enum(["WPA", "WEP", "none"])
    .optional()
    .describe("WiFi encryption type"),
});

export const AddContactActionSchema = z.object({
  type: z.literal("add-contact"),
  firstName: z.string().min(1).describe("Contact first name"),
  lastName: z.string().min(1).describe("Contact last name"),
  emails: z.array(TypedValueSchema).optional().describe("Contact email addresses"),
  phones: z.array(TypedValueSchema).optional().describe("Contact phone numbers"),
  company: z.string().optional().describe("Company or organization"),
  jobTitle: z.string().optional().describe("Job title or role"),
  website: z.string().url().optional().describe("Website URL"),
  address: AddressSchema.optional().describe("Contact address"),
  socialProfiles: z.array(NameValueSchema).optional().describe("Social media profiles"),
  instantMessaging: z.array(NameValueSchema).optional().describe("Instant messaging accounts"),
  wallets: z.array(NameValueSchema).optional().describe("Web3 wallet addresses"),
});

export const CryptoWalletActionSchema = z.object({
  type: z.literal("crypto-wallet"),
  label: z.string().min(1).describe("Display label for the wallet (e.g., 'My ETH Wallet')"),
  network: z.string().min(1).describe("Blockchain network name (e.g., 'Ethereum', 'Bitcoin', 'Solana')"),
  address: z.string().min(1).describe("Wallet address"),
});

export const ActionSchema = z
  .discriminatedUnion("type", [
    URLActionSchema,
    WifiActionSchema,
    AddContactActionSchema,
    CryptoWalletActionSchema,
  ])
  .describe("An action associated with the note");

export const BusinessCardSchema = z.object({
  firstName: z.string().min(1).describe("First name"),
  lastName: z.string().min(1).describe("Last name"),
  emails: z.array(TypedValueSchema).optional().describe("Email addresses with types"),
  phones: z.array(TypedValueSchema).optional().describe("Phone numbers with types"),
  company: z.string().optional().describe("Company or organization"),
  jobTitle: z.string().optional().describe("Job title or role"),
  website: z.string().url().optional().describe("Website URL"),
  address: AddressSchema.optional().describe("Structured address"),
  imageUrl: z
    .string()
    .nullable()
    .optional()
    .describe(
      "Profile image (file:N reference in requests, signed URL in responses)"
    ),
  imageFileId: z
    .number()
    .int()
    .nullable()
    .optional()
    .describe("Profile image file ID (populated in responses for editing)"),
  socialProfiles: z.array(NameValueSchema).optional().describe("Social media profiles"),
  instantMessaging: z.array(NameValueSchema).optional().describe("Instant messaging accounts"),
  wallets: z.array(NameValueSchema).optional().describe("Web3 wallet addresses"),
});

// Signed image with ID and URL
export const SignedImageSchema = z.object({
  id: z.number().int().describe("File ID"),
  url: z.string().url().describe("Signed image URL"),
});

// Insert schema
export const NoteInsertSchema = z.object({
  title: z.string().min(1).describe("Note title"),
  type: z
    .enum(["regular-text-note", "business-card"])
    .optional()
    .describe("Note type"),
  note: z.string().nullable().optional().describe("Markdown note content"),
  businessCard: BusinessCardSchema
    .nullable()
    .optional()
    .describe("Business card data"),
  images: z
    .array(z.string())
    .optional()
    .describe("Image file references (file:N format)"),
  audios: z
    .array(z.string())
    .optional()
    .describe("Audio file references (file:N format)"),
  videos: z
    .array(z.string())
    .optional()
    .describe("Video file references (file:N format)"),
  latitude: z.number().nullable().optional().describe("Latitude coordinate"),
  longitude: z.number().nullable().optional().describe("Longitude coordinate"),
  actions: z
    .array(ActionSchema)
    .optional()
    .describe("Actions associated with the note"),
  visibility: z
    .enum(["public", "private", "auth-only"])
    .describe("Visibility setting"),
});

// Update schema
export const NoteUpdateSchema = z.object({
  title: z.string().min(1).optional().describe("Note title"),
  type: z
    .enum(["regular-text-note", "business-card"])
    .optional()
    .describe("Note type"),
  note: z.string().nullable().optional().describe("Markdown note content"),
  businessCard: BusinessCardSchema
    .nullable()
    .optional()
    .describe("Business card data"),
  images: z
    .array(z.string())
    .optional()
    .describe("Image file references (file:N format)"),
  audios: z
    .array(z.string())
    .optional()
    .describe("Audio file references (file:N format)"),
  videos: z
    .array(z.string())
    .optional()
    .describe("Video file references (file:N format)"),
  latitude: z.number().nullable().optional().describe("Latitude coordinate"),
  longitude: z.number().nullable().optional().describe("Longitude coordinate"),
  actions: z
    .array(ActionSchema)
    .optional()
    .describe("Actions associated with the note"),
  visibility: z
    .enum(["public", "private", "auth-only"])
    .optional()
    .describe("Visibility setting"),
});

// Response schema
export const NoteResponseSchema = z.object({
  id: z.string().describe("Unique note identifier"),
  userId: z.string().describe("Owner user ID"),
  type: z.enum(["regular-text-note", "business-card"]).describe("Note type"),
  title: z.string().describe("Note title"),
  note: z.string().nullable().describe("Markdown note content"),
  businessCard: BusinessCardSchema.nullable().describe("Business card data"),
  images: z.array(SignedImageSchema).describe("Signed images with IDs and URLs"),
  audios: z.array(z.string()).describe("Audio file references"),
  videos: z.array(z.string()).describe("Video file references"),
  latitude: z.number().nullable().describe("Latitude coordinate"),
  longitude: z.number().nullable().describe("Longitude coordinate"),
  actions: z.array(ActionSchema).describe("Actions associated with the note"),
  visibility: z
    .enum(["public", "private", "auth-only"])
    .describe("Visibility setting"),
  previewUrl: z.string().url().describe("Public preview URL for the note"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
  updatedAt: z.coerce.date().describe("Last update timestamp"),
});

// Detail response with whitelist
export const NoteDetailResponseSchema = NoteResponseSchema.extend({
  whitelist: z
    .array(
      z.object({
        id: z.number().int().describe("Whitelist entry ID"),
        email: z.string().describe("Whitelisted email"),
        createdAt: z.coerce.date().describe("Creation timestamp"),
      })
    )
    .optional()
    .describe("Whitelist entries (only for owner)"),
});

// Query params
export const NotesQueryParams = PaginationQueryParams.extend({
  search: z
    .string()
    .optional()
    .describe("Search query for title/note content"),
  visibility: z
    .enum(["public", "private", "auth-only"])
    .optional()
    .describe("Filter by visibility"),
});

// Paginated response
export const PaginatedNotesResponse = z.object({
  data: z.array(NoteResponseSchema).describe("Array of notes"),
  pagination: PaginationInfo,
});
