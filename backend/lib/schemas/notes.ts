import { z } from "zod";
import { PaginationInfo, PaginationQueryParams } from "./common";

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

export const ActionSchema = z
  .discriminatedUnion("type", [URLActionSchema, WifiActionSchema])
  .describe("An action associated with the note");

// Signed image with ID and URL
export const SignedImageSchema = z.object({
  id: z.number().int().describe("File ID"),
  url: z.string().url().describe("Signed image URL"),
});

// Insert schema
export const NoteInsertSchema = z.object({
  title: z.string().min(1).describe("Note title"),
  type: z
    .enum(["regular-text-note"])
    .optional()
    .describe("Note type"),
  note: z.string().nullable().optional().describe("Markdown note content"),
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
    .enum(["regular-text-note"])
    .optional()
    .describe("Note type"),
  note: z.string().nullable().optional().describe("Markdown note content"),
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
  id: z.number().int().describe("Unique note identifier"),
  userId: z.string().describe("Owner user ID"),
  type: z.enum(["regular-text-note"]).describe("Note type"),
  title: z.string().describe("Note title"),
  note: z.string().nullable().describe("Markdown note content"),
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
