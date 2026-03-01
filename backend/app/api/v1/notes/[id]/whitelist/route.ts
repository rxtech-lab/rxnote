import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getNote } from "@/lib/actions/note-actions";
import {
  getNoteWhitelist,
  addToNoteWhitelistAction,
  removeFromNoteWhitelistAction,
} from "@/lib/actions/note-whitelist-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * List whitelist entries
 * @operationId getNoteWhitelist
 * @description Returns all whitelisted emails for a private note (owner only)
 * @pathParams IdPathParams
 * @response NoteWhitelistListResponse
 * @auth bearer
 * @tag Whitelists
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const noteId = parseInt(id);

  if (isNaN(noteId)) {
    return NextResponse.json({ error: "Invalid note ID" }, { status: 400 });
  }

  const note = await getNote(noteId);
  if (!note) {
    return NextResponse.json({ error: "Note not found" }, { status: 404 });
  }

  if (note.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  const whitelist = await getNoteWhitelist(noteId);
  return NextResponse.json(whitelist);
}

/**
 * Add to whitelist
 * @operationId addToNoteWhitelist
 * @description Add an email address to the whitelist for accessing a private note
 * @pathParams IdPathParams
 * @body NoteWhitelistAddRequestSchema
 * @response 201:NoteWhitelistResponseSchema
 * @auth bearer
 * @tag Whitelists
 * @responseSet auth
 * @openapi
 */
export async function POST(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const noteId = parseInt(id);

  if (isNaN(noteId)) {
    return NextResponse.json({ error: "Invalid note ID" }, { status: 400 });
  }

  const note = await getNote(noteId);
  if (!note) {
    return NextResponse.json({ error: "Note not found" }, { status: 404 });
  }

  if (note.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  const body = await request.json();
  const { email } = body as { email: string };

  if (!email) {
    return NextResponse.json(
      { error: "Missing required field: email" },
      { status: 400 }
    );
  }

  const result = await addToNoteWhitelistAction({ noteId, email });

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  return NextResponse.json(result.data, { status: 201 });
}

/**
 * Remove from whitelist
 * @operationId removeFromNoteWhitelist
 * @description Remove an email from the whitelist
 * @pathParams IdPathParams
 * @body NoteWhitelistRemoveRequestSchema
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Whitelists
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const noteId = parseInt(id);

  if (isNaN(noteId)) {
    return NextResponse.json({ error: "Invalid note ID" }, { status: 400 });
  }

  const note = await getNote(noteId);
  if (!note) {
    return NextResponse.json({ error: "Note not found" }, { status: 404 });
  }

  if (note.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  const body = await request.json();
  const { whitelistId } = body as { whitelistId: number };

  if (!whitelistId) {
    return NextResponse.json(
      { error: "Missing required field: whitelistId" },
      { status: 400 }
    );
  }

  const result = await removeFromNoteWhitelistAction(whitelistId);

  if (!result.success) {
    return NextResponse.json({ error: result.error }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
