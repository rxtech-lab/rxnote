import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getNotesByIds } from "@/lib/actions/note-actions";
import { isEmailWhitelistedForNote } from "@/lib/actions/note-whitelist-actions";
import { signImagesArrayWithIds, signBusinessCardImage } from "@/lib/actions/s3-upload-actions";
import {
  BatchNotesRequestSchema,
  BatchNotesResponseSchema,
  NoteResponseSchema,
} from "@/lib/schemas/notes";
import type { Note } from "@/lib/db";

/**
 * Batch fetch notes by IDs
 * @operationId batchGetNotes
 * @description Fetch multiple notes by their IDs. Only returns notes the caller has permission to access. Public notes are accessible without authentication.
 * @body BatchNotesRequestSchema
 * @response BatchNotesResponseSchema
 * @tag Notes
 * @responseSet public
 * @openapi
 */
export async function POST(request: NextRequest) {
  const session = await getSession(request);

  let body;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "Invalid request body" },
      { status: 400 },
    );
  }

  const parsed = BatchNotesRequestSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Invalid request body" },
      { status: 400 },
    );
  }

  const { ids } = parsed.data;
  const allNotes = await getNotesByIds(ids);

  const accessibleNotes: Note[] = [];
  for (const note of allNotes) {
    if (note.visibility === "public") {
      accessibleNotes.push(note);
      continue;
    }

    if (!session) continue;

    if (note.visibility === "auth-only") {
      accessibleNotes.push(note);
      continue;
    }

    // Private: owner or whitelisted
    if (note.userId === session.user.id) {
      accessibleNotes.push(note);
      continue;
    }

    if (session.user.email) {
      const whitelisted = await isEmailWhitelistedForNote(note.id, session.user.email);
      if (whitelisted) {
        accessibleNotes.push(note);
      }
    }
  }

  const dataWithSignedImages = await Promise.all(
    accessibleNotes.map(async (note) => {
      const images =
        note.images && (note.images as string[]).length > 0
          ? await signImagesArrayWithIds(note.images as string[])
          : [];
      const businessCard = await signBusinessCardImage(
        note.businessCard as Record<string, unknown> | null,
      );
      return NoteResponseSchema.parse({
        ...note,
        businessCard,
        images,
        audios: (note.audios as string[]) || [],
        videos: (note.videos as string[]) || [],
        actions: (note.actions as unknown[]) || [],
        previewUrl: `${process.env.NEXT_PUBLIC_URL}/preview/note?id=${note.id}`,
      });
    }),
  );

  const response = BatchNotesResponseSchema.parse({
    data: dataWithSignedImages,
  });

  return NextResponse.json(response);
}
