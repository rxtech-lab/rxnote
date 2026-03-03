"use server";

import { revalidatePath } from "next/cache";
import { eq, like, or, desc, asc, and, lt, gt } from "drizzle-orm";
import {
  db,
  notes,
  type Note,
  type NewNote,
} from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";
import {
  validateFileOwnership,
  validateFilesExistInS3,
  associateFilesWithNote,
  disassociateFilesFromNote,
  deleteFilesForNote,
} from "./file-actions";
import { parseFileIds, isFileId } from "@/lib/utils/file-utils";
import {
  type PaginationParams,
  type PaginatedResult,
  decodeCursor,
  buildPaginatedResponse,
  DEFAULT_PAGE_SIZE,
} from "@/lib/utils/pagination";

export interface NoteFilters {
  userId?: string;
  visibility?: "public" | "private" | "auth-only";
  search?: string;
}

export interface PaginatedNoteFilters extends NoteFilters, PaginationParams {}

function isValidBusinessCard(
  businessCard: NewNote["businessCard"] | null | undefined,
): businessCard is NonNullable<NewNote["businessCard"]> {
  return Boolean(
    businessCard
      && typeof businessCard.firstName === "string"
      && businessCard.firstName.trim().length > 0
      && typeof businessCard.lastName === "string"
      && businessCard.lastName.trim().length > 0,
  );
}

export async function getNotes(
  userId?: string,
  filters?: NoteFilters,
): Promise<Note[]> {
  await ensureSchemaInitialized();

  const session = await getSession();
  if (!session?.user?.id && !userId) {
    return [];
  }
  const sessionUserId = session?.user.id ?? userId;
  if (!sessionUserId) {
    return [];
  }

  const conditions = [eq(notes.userId, sessionUserId)];

  if (filters?.visibility) {
    conditions.push(eq(notes.visibility, filters.visibility));
  }
  if (filters?.search) {
    const searchCondition = or(
      like(notes.title, `%${filters.search}%`),
      like(notes.note, `%${filters.search}%`),
    );
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  return db
    .select()
    .from(notes)
    .where(and(...conditions))
    .orderBy(desc(notes.updatedAt));
}

export async function getNote(id: string): Promise<Note | undefined> {
  await ensureSchemaInitialized();
  const results = await db
    .select()
    .from(notes)
    .where(eq(notes.id, id))
    .limit(1);

  return results[0];
}

export async function createNoteAction(
  data: Omit<NewNote, "id" | "userId" | "createdAt" | "updatedAt">,
  userId?: string,
): Promise<{ success: boolean; data?: Note; error?: string }> {
  try {
    await ensureSchemaInitialized();

    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    const images = (data.images as string[]) || [];
    const audios = (data.audios as string[]) || [];
    const videos = (data.videos as string[]) || [];

    // Validate file IDs across all media arrays
    const allFileRefs = [...images, ...audios, ...videos];

    // Include business card image in file validation
    const bcImageUrl = data.businessCard?.imageUrl;
    if (bcImageUrl && isFileId(bcImageUrl)) {
      allFileRefs.push(bcImageUrl);
    }

    const fileIds = parseFileIds(allFileRefs);
    if (fileIds.length > 0) {
      const ownershipResult = await validateFileOwnership(fileIds, resolvedUserId);
      if (!ownershipResult.valid) {
        return { success: false, error: ownershipResult.error };
      }
      const s3Result = await validateFilesExistInS3(fileIds);
      if (!s3Result.valid) {
        return { success: false, error: s3Result.error };
      }
    }

    const now = new Date();
    const noteType = data.type || "regular-text-note" as const;
    let businessCard = data.businessCard ?? null;

    if (noteType === "business-card") {
      if (!isValidBusinessCard(businessCard)) {
        return {
          success: false,
          error: "Business card notes require firstName and lastName",
        };
      }
      // Strip imageFileId from stored data (it's response-only)
      if (businessCard) {
        const { imageFileId: _, ...bcData } = businessCard as unknown as Record<string, unknown>;
        businessCard = bcData as unknown as typeof businessCard;
      }
    } else {
      businessCard = null;
    }

    const insertData = {
      userId: resolvedUserId,
      type: noteType,
      title: data.title,
      note: data.note || null,
      businessCard,
      images,
      audios,
      videos,
      latitude: data.latitude ?? null,
      longitude: data.longitude ?? null,
      actions: data.actions || [],
      visibility: data.visibility || "private" as const,
      createdAt: now,
      updatedAt: now,
    };

    const result = await db.insert(notes).values(insertData).returning();

    if (fileIds.length > 0) {
      await associateFilesWithNote(fileIds, result[0].id, resolvedUserId);
    }

    revalidatePath("/");
    return { success: true, data: result[0] };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to create note",
    };
  }
}

export async function updateNoteAction(
  id: string,
  data: Partial<Omit<NewNote, "id" | "userId" | "createdAt" | "updatedAt">>,
  userId?: string,
): Promise<{ success: boolean; data?: Note; error?: string }> {
  try {
    await ensureSchemaInitialized();

    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    const existing = await db
      .select({
        userId: notes.userId,
        type: notes.type,
        businessCard: notes.businessCard,
        images: notes.images,
        audios: notes.audios,
        videos: notes.videos,
      })
      .from(notes)
      .where(eq(notes.id, id))
      .limit(1);

    if (!existing[0] || existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    // Handle file ID changes for images
    if (data.images !== undefined) {
      const newImages = (data.images as string[]) || [];
      const oldImages = (existing[0].images as string[]) || [];
      const newFileIds = parseFileIds(newImages);
      const oldFileIds = parseFileIds(oldImages);
      const addedFileIds = newFileIds.filter((fid) => !oldFileIds.includes(fid));
      const removedFileIds = oldFileIds.filter((fid) => !newFileIds.includes(fid));

      if (addedFileIds.length > 0) {
        const ownershipResult = await validateFileOwnership(addedFileIds, resolvedUserId);
        if (!ownershipResult.valid) {
          return { success: false, error: ownershipResult.error };
        }
        const s3Result = await validateFilesExistInS3(addedFileIds);
        if (!s3Result.valid) {
          return { success: false, error: s3Result.error };
        }
        await associateFilesWithNote(addedFileIds, id, resolvedUserId);
      }
      if (removedFileIds.length > 0) {
        await disassociateFilesFromNote(removedFileIds);
      }
    }

    // Handle business card image file changes
    if (data.businessCard !== undefined) {
      const newBcImageUrl = data.businessCard?.imageUrl;
      const oldBcImageUrl = (existing[0].businessCard as unknown as Record<string, unknown> | null)?.imageUrl as string | undefined;
      const newBcFileIds = newBcImageUrl && isFileId(newBcImageUrl) ? parseFileIds([newBcImageUrl]) : [];
      const oldBcFileIds = oldBcImageUrl && isFileId(oldBcImageUrl) ? parseFileIds([oldBcImageUrl]) : [];
      const addedBcFileIds = newBcFileIds.filter((fid) => !oldBcFileIds.includes(fid));
      const removedBcFileIds = oldBcFileIds.filter((fid) => !newBcFileIds.includes(fid));

      if (addedBcFileIds.length > 0) {
        const ownershipResult = await validateFileOwnership(addedBcFileIds, resolvedUserId);
        if (!ownershipResult.valid) {
          return { success: false, error: ownershipResult.error };
        }
        const s3Result = await validateFilesExistInS3(addedBcFileIds);
        if (!s3Result.valid) {
          return { success: false, error: s3Result.error };
        }
        await associateFilesWithNote(addedBcFileIds, id, resolvedUserId);
      }
      if (removedBcFileIds.length > 0) {
        await disassociateFilesFromNote(removedBcFileIds);
      }
    }

    const updateData = { ...data, updatedAt: new Date() };

    const nextType = data.type ?? existing[0].type;
    const nextBusinessCard = data.businessCard !== undefined
      ? data.businessCard
      : existing[0].businessCard;

    if (nextType === "business-card") {
      if (!isValidBusinessCard(nextBusinessCard)) {
        return {
          success: false,
          error: "Business card notes require firstName and lastName",
        };
      }
      // Strip imageFileId from stored data (it's response-only)
      if (updateData.businessCard) {
        const { imageFileId: _, ...bcData } = updateData.businessCard as unknown as Record<string, unknown>;
        updateData.businessCard = bcData as unknown as typeof updateData.businessCard;
      }
    } else {
      updateData.businessCard = null;
    }

    await db
      .update(notes)
      .set(updateData)
      .where(eq(notes.id, id));

    revalidatePath("/");

    const updatedNote = await getNote(id);
    if (!updatedNote) {
      return { success: false, error: "Note not found after update" };
    }
    return { success: true, data: updatedNote };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to update note",
    };
  }
}

export async function deleteNoteAction(
  id: string,
  userId?: string,
): Promise<{ success: boolean; error?: string }> {
  try {
    await ensureSchemaInitialized();

    let resolvedUserId = userId;
    if (!resolvedUserId) {
      const session = await getSession();
      if (!session?.user?.id) {
        return { success: false, error: "Unauthorized" };
      }
      resolvedUserId = session.user.id;
    }

    const existing = await db
      .select({ userId: notes.userId })
      .from(notes)
      .where(eq(notes.id, id))
      .limit(1);

    if (!existing[0]) {
      return { success: false, error: "Note not found" };
    }

    if (existing[0].userId !== resolvedUserId) {
      return { success: false, error: "Permission denied" };
    }

    await deleteFilesForNote(id);
    await db.delete(notes).where(eq(notes.id, id));

    revalidatePath("/");
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Failed to delete note",
    };
  }
}

export async function getNotesPaginated(
  userId?: string,
  filters?: PaginatedNoteFilters,
): Promise<PaginatedResult<Note>> {
  await ensureSchemaInitialized();

  const session = await getSession();
  const sessionUserId = userId ?? session?.user?.id;
  if (!sessionUserId) {
    return {
      data: [],
      pagination: {
        nextCursor: null,
        prevCursor: null,
        hasNextPage: false,
        hasPrevPage: false,
      },
    };
  }

  const limit = filters?.limit ?? DEFAULT_PAGE_SIZE;
  const direction = filters?.direction ?? "next";
  const cursor = filters?.cursor ? decodeCursor(filters.cursor) : null;

  const conditions = [eq(notes.userId, sessionUserId)];

  if (filters?.visibility) {
    conditions.push(eq(notes.visibility, filters.visibility));
  }
  if (filters?.search) {
    const searchCondition = or(
      like(notes.title, `%${filters.search}%`),
      like(notes.note, `%${filters.search}%`),
    );
    if (searchCondition) {
      conditions.push(searchCondition);
    }
  }

  if (cursor) {
    const cursorDate = new Date(cursor.sortValue);
    const cursorId = cursor.id;

    if (direction === "next") {
      const cursorCondition = or(
        lt(notes.updatedAt, cursorDate),
        and(eq(notes.updatedAt, cursorDate), lt(notes.id, cursorId)),
      );
      if (cursorCondition) conditions.push(cursorCondition);
    } else {
      const cursorCondition = or(
        gt(notes.updatedAt, cursorDate),
        and(eq(notes.updatedAt, cursorDate), gt(notes.id, cursorId)),
      );
      if (cursorCondition) conditions.push(cursorCondition);
    }
  }

  let query = db
    .select()
    .from(notes)
    .$dynamic();

  if (conditions.length > 0) {
    query = query.where(and(...conditions));
  }

  if (direction === "next") {
    query = query.orderBy(desc(notes.updatedAt), desc(notes.id));
  } else {
    query = query.orderBy(asc(notes.updatedAt), asc(notes.id));
  }

  query = query.limit(limit + 1);

  const results = await query;

  return buildPaginatedResponse(
    results,
    limit,
    direction,
    (note) => note.updatedAt.toISOString(),
    !!cursor,
  );
}
