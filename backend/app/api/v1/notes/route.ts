import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getNotesPaginated,
  createNoteAction,
  type NoteFilters,
  type PaginatedNoteFilters,
} from "@/lib/actions/note-actions";
import { signImagesArrayWithIds, signBusinessCardImage } from "@/lib/actions/s3-upload-actions";
import { parsePaginationParams } from "@/lib/utils/pagination";
import { PaginatedNotesResponse, NoteResponseSchema } from "@/lib/schemas/notes";

/**
 * List notes
 * @operationId getNotes
 * @description Retrieve a paginated list of notes with optional filters. Supports cursor-based pagination.
 * @params NotesQueryParams
 * @response PaginatedNotesResponse
 * @auth bearer
 * @tag Notes
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const searchParams = request.nextUrl.searchParams;
  const filters: NoteFilters = {
    userId: session.user.id,
  };

  if (searchParams.has("visibility")) {
    filters.visibility = searchParams.get("visibility") as "public" | "private" | "auth-only";
  }
  if (searchParams.has("search")) {
    filters.search = searchParams.get("search")!;
  }

  const paginationParams = parsePaginationParams({
    cursor: searchParams.get("cursor"),
    direction: searchParams.get("direction"),
    limit: searchParams.get("limit"),
  });

  const paginatedFilters: PaginatedNoteFilters = {
    ...filters,
    ...paginationParams,
  };

  const result = await getNotesPaginated(session.user.id, paginatedFilters);

  const dataWithSignedImages = await Promise.all(
    result.data.map(async (note) => {
      const images =
        note.images && (note.images as string[]).length > 0
          ? await signImagesArrayWithIds(note.images as string[])
          : [];
      const businessCard = await signBusinessCardImage(
        note.businessCard as Record<string, unknown> | null
      );
      return {
        ...note,
        businessCard,
        images,
        audios: (note.audios as string[]) || [],
        videos: (note.videos as string[]) || [],
        actions: (note.actions as unknown[]) || [],
        previewUrl: `${process.env.NEXT_PUBLIC_URL}/preview/note?id=${note.id}`,
      };
    })
  );

  const response = PaginatedNotesResponse.parse({
    data: dataWithSignedImages,
    pagination: result.pagination,
  });

  return NextResponse.json(response);
}

/**
 * Create note
 * @operationId createNote
 * @description Create a new note
 * @body NoteInsertSchema
 * @response 201:NoteResponseSchema
 * @auth bearer
 * @tag Notes
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const body = await request.json();
    const result = await createNoteAction(body, session.user.id);

    if (result.success && result.data) {
      const images =
        result.data.images && (result.data.images as string[]).length > 0
          ? await signImagesArrayWithIds(result.data.images as string[])
          : [];

      const previewUrl = `${process.env.NEXT_PUBLIC_URL}/preview/note?id=${result.data.id}`;
      const businessCard = await signBusinessCardImage(
        result.data.businessCard as Record<string, unknown> | null
      );

      const response = NoteResponseSchema.parse({
        ...result.data,
        businessCard,
        images,
        audios: (result.data.audios as string[]) || [],
        videos: (result.data.videos as string[]) || [],
        actions: (result.data.actions as unknown[]) || [],
        previewUrl,
      });

      return NextResponse.json(response, { status: 201 });
    } else {
      return NextResponse.json({ error: result.error }, { status: 400 });
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 }
    );
  }
}
