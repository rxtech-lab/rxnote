import { z } from "zod";

export const NoteWhitelistResponseSchema = z.object({
  id: z.number().int().describe("Unique whitelist entry identifier"),
  noteId: z.number().int().describe("Associated note ID"),
  email: z.string().describe("Whitelisted email address"),
  createdAt: z.coerce.date().describe("Creation timestamp"),
});

export const NoteWhitelistAddRequestSchema = z.object({
  email: z.string().email().describe("Email address to whitelist"),
});

export const NoteWhitelistRemoveRequestSchema = z.object({
  whitelistId: z.number().int().describe("Whitelist entry ID to remove"),
});

export const NoteWhitelistListResponse = z.array(NoteWhitelistResponseSchema);
