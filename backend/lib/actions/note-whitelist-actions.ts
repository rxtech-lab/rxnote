"use server";

import { revalidatePath } from "next/cache";
import { eq, and } from "drizzle-orm";
import { db, noteWhitelists, type NoteWhitelist, type NewNoteWhitelist } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";

export async function getNoteWhitelist(noteId: number): Promise<NoteWhitelist[]> {
  await ensureSchemaInitialized();
  return db
    .select()
    .from(noteWhitelists)
    .where(eq(noteWhitelists.noteId, noteId))
    .orderBy(noteWhitelists.email);
}

export async function isEmailWhitelistedForNote(noteId: number, email: string): Promise<boolean> {
  const results = await db
    .select()
    .from(noteWhitelists)
    .where(
      and(
        eq(noteWhitelists.noteId, noteId),
        eq(noteWhitelists.email, email.toLowerCase())
      )
    )
    .limit(1);
  return results.length > 0;
}

export async function addToNoteWhitelistAction(
  data: Omit<NewNoteWhitelist, "id" | "createdAt">
): Promise<{ success: boolean; data?: NoteWhitelist; error?: string }> {
  try {
    const normalizedData = {
      ...data,
      email: data.email.toLowerCase(),
    };

    const existing = await db
      .select()
      .from(noteWhitelists)
      .where(
        and(
          eq(noteWhitelists.noteId, normalizedData.noteId),
          eq(noteWhitelists.email, normalizedData.email)
        )
      )
      .limit(1);

    if (existing.length > 0) {
      return { success: true, data: existing[0] };
    }

    const result = await db.insert(noteWhitelists).values(normalizedData).returning();
    revalidatePath("/");
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to add to whitelist",
    };
  }
}

export async function removeFromNoteWhitelistAction(
  id: number
): Promise<{ success: boolean; error?: string }> {
  try {
    await db.delete(noteWhitelists).where(eq(noteWhitelists.id, id));
    revalidatePath("/");
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to remove from whitelist",
    };
  }
}
