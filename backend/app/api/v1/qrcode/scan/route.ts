import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getNote } from "@/lib/actions/note-actions";
import { isEmailWhitelistedForNote } from "@/lib/actions/note-whitelist-actions";
import {
  QrCodeScanRequestSchema,
  QrCodeScanResponseSchema,
} from "@/lib/schemas/qrcode";
import type { Note } from "@/lib/db";

interface PermissionResult {
  error?: string;
  status?: number;
}

interface Session {
  user: {
    id: string;
    email?: string | null;
  };
}

/**
 * Check if the user has permission to access the note
 */
async function checkNotePermission(
  note: Note,
  session: Session | null,
): Promise<PermissionResult> {
  // Public notes are accessible to anyone
  if (note.visibility === "public") {
    return {};
  }

  // Auth-only and private notes require auth
  if (!session) {
    return { error: "Unauthorized", status: 401 };
  }

  // Auth-only: any authenticated user can access
  if (note.visibility === "auth-only") {
    return {};
  }

  // Private: owner always has access
  if (note.userId === session.user.id) {
    return {};
  }

  // Check whitelist
  if (session.user.email) {
    const whitelisted = await isEmailWhitelistedForNote(note.id, session.user.email);
    if (whitelisted) {
      return {};
    }
  }

  return { error: "Permission denied", status: 403 };
}

/**
 * Scan QR code and resolve to note URL
 * @operationId scanQrCode
 * @description Scan a QR code content and resolve it to a note API URL. Supports preview URL format (preview/note/:id and preview/note?id=).
 * @body QrCodeScanRequestSchema
 * @response QrCodeScanResponseSchema
 * @auth bearer
 * @tag QRCode
 * @responseSet auth
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

  const parsed = QrCodeScanRequestSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Invalid request body" },
      { status: 400 },
    );
  }

  const { qrcontent } = parsed.data;
  const baseUrl = process.env.NEXT_PUBLIC_URL || "http://localhost:3000";

  // Pattern A1: Match preview/note?id=:id format (query param)
  const queryParamMatch = qrcontent.match(/(?:^|\/)?preview\/note\?id=([a-zA-Z0-9_-]+)(?:$|&|#)/);
  if (queryParamMatch) {
    const noteId = queryParamMatch[1];
    const note = await getNote(noteId);

    if (!note) {
      return NextResponse.json({ error: "Invalid QR code" }, { status: 400 });
    }

    const permissionResult = await checkNotePermission(note, session);
    if (permissionResult.error) {
      return NextResponse.json(
        { error: permissionResult.error },
        { status: permissionResult.status },
      );
    }

    const response = QrCodeScanResponseSchema.parse({
      type: "note",
      url: `${baseUrl}/api/v1/notes/${noteId}`,
    });

    return NextResponse.json(response);
  }

  // Pattern A2: Match preview/note/:id format (path param)
  const previewMatch = qrcontent.match(/(?:^|\/)?preview\/note\/([a-zA-Z0-9_-]+)(?:$|[?#])/);
  if (previewMatch) {
    const noteId = previewMatch[1];
    const note = await getNote(noteId);

    if (!note) {
      return NextResponse.json({ error: "Invalid QR code" }, { status: 400 });
    }

    const permissionResult = await checkNotePermission(note, session);
    if (permissionResult.error) {
      return NextResponse.json(
        { error: permissionResult.error },
        { status: permissionResult.status },
      );
    }

    const response = QrCodeScanResponseSchema.parse({
      type: "note",
      url: `${baseUrl}/api/v1/notes/${noteId}`,
    });

    return NextResponse.json(response);
  }

  // No match found
  return NextResponse.json({ error: "Invalid QR code" }, { status: 400 });
}
