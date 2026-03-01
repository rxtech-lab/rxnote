import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getNote,
  updateNoteAction,
  deleteNoteAction,
} from "@/lib/actions/note-actions";
import { getNoteWhitelist, isEmailWhitelistedForNote } from "@/lib/actions/note-whitelist-actions";
import { signImagesArrayWithIds } from "@/lib/actions/s3-upload-actions";
import {
  NoteDetailResponseSchema,
  NoteResponseSchema,
} from "@/lib/schemas/notes";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * Get note by ID
 * @operationId getNote
 * @description Retrieve detailed note information. Public notes can be accessed without authentication.
 * @pathParams IdPathParams
 * @response NoteDetailResponseSchema
 * @tag Notes
 * @responseSet public
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
  const { id } = await params;
  const noteId = parseInt(id);
  const note = await getNote(noteId);

  if (!note) {
    return NextResponse.json({ error: "Note not found" }, { status: 404 });
  }

  // Public notes can be accessed without authentication
  if (note.visibility === "public") {
    return buildNoteResponse(note, null);
  }

  // Auth-only and private notes require authentication
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  // Auth-only: any authenticated user can access
  if (note.visibility === "auth-only") {
    return buildNoteResponse(note, session.user.id);
  }

  // Private: owner or whitelisted user only
  if (note.userId !== session.user.id) {
    if (session.user.email) {
      const whitelisted = await isEmailWhitelistedForNote(noteId, session.user.email);
      if (!whitelisted) {
        return NextResponse.json({ error: "Permission denied" }, { status: 403 });
      }
    } else {
      return NextResponse.json({ error: "Permission denied" }, { status: 403 });
    }
  }

  return buildNoteResponse(note, session.user.id);
}

async function buildNoteResponse(
  note: NonNullable<Awaited<ReturnType<typeof getNote>>>,
  userId: string | null,
) {
  const previewUrl = `${process.env.NEXT_PUBLIC_URL}/preview/note?id=${note.id}`;

  const [images, whitelist] = await Promise.all([
    note.images && (note.images as string[]).length > 0
      ? signImagesArrayWithIds(note.images as string[])
      : Promise.resolve([]),
    // Only fetch whitelist for the owner
    userId && note.userId === userId
      ? getNoteWhitelist(note.id)
      : Promise.resolve(undefined),
  ]);

  const responseData = {
    ...note,
    images,
    audios: (note.audios as string[]) || [],
    videos: (note.videos as string[]) || [],
    actions: (note.actions as unknown[]) || [],
    previewUrl,
    whitelist,
  };

  const validated = NoteDetailResponseSchema.safeParse(responseData);
  if (!validated.success) {
    console.error("Validation error:", validated.error.errors);
    return NextResponse.json(
      { error: "Invalid response data" },
      { status: 500 },
    );
  }
  return NextResponse.json(validated.data);
}

/**
 * Update note
 * @operationId updateNote
 * @description Update an existing note
 * @pathParams IdPathParams
 * @body NoteUpdateSchema
 * @response NoteResponseSchema
 * @auth bearer
 * @tag Notes
 * @responseSet auth
 * @openapi
 */
export async function PUT(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  try {
    const body = await request.json();
    const result = await updateNoteAction(parseInt(id), body, session.user.id);

    if (result.success && result.data) {
      const previewUrl = `${process.env.NEXT_PUBLIC_URL}/preview/note?id=${result.data.id}`;

      const images =
        result.data.images && (result.data.images as string[]).length > 0
          ? await signImagesArrayWithIds(result.data.images as string[])
          : [];

      const responseData = {
        ...result.data,
        images,
        audios: (result.data.audios as string[]) || [],
        videos: (result.data.videos as string[]) || [],
        actions: (result.data.actions as unknown[]) || [],
        previewUrl,
      };
      const validated = NoteResponseSchema.parse(responseData);
      return NextResponse.json(validated);
    } else if (result.error === "Permission denied") {
      return NextResponse.json({ error: result.error }, { status: 403 });
    } else {
      return NextResponse.json({ error: result.error }, { status: 400 });
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 },
    );
  }
}

/**
 * Delete note
 * @operationId deleteNote
 * @description Delete a note by ID
 * @pathParams IdPathParams
 * @response 204:NoContent
 * @auth bearer
 * @tag Notes
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteNoteAction(parseInt(id), session.user.id);

  if (result.success) {
    return new NextResponse(null, { status: 204 });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else if (result.error === "Note not found") {
    return NextResponse.json({ error: result.error }, { status: 404 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
