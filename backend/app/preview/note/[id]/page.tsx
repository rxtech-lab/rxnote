import { notFound, redirect } from "next/navigation";
import { headers } from "next/headers";
import { Metadata } from "next";
import { auth } from "@/auth";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { MapPin, Lock, Calendar, ExternalLink, Wifi } from "lucide-react";
import { LocationDisplay } from "@/components/maps/location-display";
import { getNote } from "@/lib/actions/note-actions";
import { isEmailWhitelistedForNote } from "@/lib/actions/note-whitelist-actions";
import { signImageUrlsAction } from "@/lib/actions/s3-upload-actions";
import { formatDistanceToNow, format } from "date-fns";
import type { Action } from "@/lib/db/schema/notes";

interface PreviewPageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({
  params,
}: PreviewPageProps): Promise<Metadata> {
  const { id } = await params;
  const note = await getNote(parseInt(id));

  if (!note) {
    return { title: "Note Not Found" };
  }

  const appClipBundleId = process.env.APPLE_APP_CLIP_BUNDLE_ID;

  return {
    title: note.title,
    description: note.note?.slice(0, 200) || `View ${note.title}`,
    ...(appClipBundleId && {
      other: {
        "apple-itunes-app": `app-clip-bundle-id=${appClipBundleId}, app-clip-display=card`,
      },
    }),
    openGraph: {
      title: note.title,
      description: note.note?.slice(0, 200) || undefined,
    },
  };
}

export default async function PreviewPage({ params }: PreviewPageProps) {
  const { id } = await params;
  const noteId = parseInt(id);

  const headersList = await headers();
  const accept = headersList.get("accept") || "";
  if (accept.includes("application/json")) {
    redirect(`/api/v1/notes/${id}`);
  }

  const note = await getNote(noteId);

  if (!note) {
    notFound();
  }

  // Check visibility
  if (note.visibility === "private") {
    const session = await auth();

    if (!session?.user) {
      redirect(`/login?callbackUrl=/preview/note/${noteId}`);
    }

    // Owner always has access
    if (note.userId !== session.user.id) {
      const hasAccess = session.user.email
        ? await isEmailWhitelistedForNote(noteId, session.user.email)
        : false;

      if (!hasAccess) {
        return (
          <div className="min-h-screen flex items-center justify-center bg-muted/30">
            <Card className="max-w-md">
              <CardContent className="pt-6 text-center">
                <Lock className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                <h1 className="text-xl font-bold mb-2">Access Restricted</h1>
                <p className="text-muted-foreground mb-4">
                  You don&apos;t have permission to view this note. Contact the
                  owner to request access.
                </p>
                <p className="text-sm text-muted-foreground">
                  Signed in as: {session.user.email}
                </p>
              </CardContent>
            </Card>
          </div>
        );
      }
    }
  } else if (note.visibility === "auth-only") {
    const session = await auth();
    if (!session?.user) {
      redirect(`/login?callbackUrl=/preview/note/${noteId}`);
    }
  }

  // Sign image URLs
  const images = (note.images as string[]) || [];
  const signedImagesResult =
    images.length > 0 ? await signImageUrlsAction(images) : null;

  const signedImageMap = new Map<string, string>();
  if (signedImagesResult?.data) {
    signedImagesResult.data.forEach((r) => {
      signedImageMap.set(r.originalUrl, r.signedUrl);
    });
  }

  const actions = (note.actions as Action[]) || [];

  return (
    <div className="min-h-screen bg-muted/30 py-8">
      <div className="max-w-4xl mx-auto px-4">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center gap-2 mb-2">
            {note.visibility === "private" && (
              <Badge variant="secondary" className="gap-1">
                <Lock className="h-3 w-3" />
                Private
              </Badge>
            )}
            {note.visibility === "auth-only" && (
              <Badge variant="secondary" className="gap-1">
                <Lock className="h-3 w-3" />
                Auth Only
              </Badge>
            )}
          </div>
          <h1 className="text-4xl font-bold mb-2">{note.title}</h1>
          <div className="flex items-center gap-4 text-sm text-muted-foreground">
            <span className="flex items-center gap-1">
              <Calendar className="h-4 w-4" />
              {format(new Date(note.createdAt), "MMM d, yyyy")}
            </span>
          </div>
        </div>

        {/* Images */}
        {images.length > 0 && (
          <div className="mb-8">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {images.map((image, index) => (
                <img
                  key={index}
                  src={signedImageMap.get(image) || image}
                  alt={`${note.title} - Image ${index + 1}`}
                  className="w-full h-64 object-cover rounded-lg"
                />
              ))}
            </div>
          </div>
        )}

        {/* Note Content (Markdown) */}
        {note.note && (
          <Card className="mb-8">
            <CardContent className="pt-6">
              <div className="prose prose-sm max-w-none whitespace-pre-wrap">
                {note.note}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Location Map */}
        {note.latitude != null && note.longitude != null && (
          <Card className="mb-8">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <MapPin className="h-5 w-5" />
                Location
              </CardTitle>
            </CardHeader>
            <CardContent>
              <LocationDisplay
                latitude={note.latitude}
                longitude={note.longitude}
                title={note.title}
                height="300px"
              />
            </CardContent>
          </Card>
        )}

        {/* Actions */}
        {actions.length > 0 && (
          <Card className="mb-8">
            <CardHeader>
              <CardTitle>Actions</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {actions.map((action, index) => {
                  if (action.type === "url") {
                    return (
                      <a
                        key={index}
                        href={action.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 p-3 rounded-lg border hover:bg-accent transition-colors"
                      >
                        <ExternalLink className="h-4 w-4" />
                        <span className="font-medium">{action.label}</span>
                      </a>
                    );
                  }
                  if (action.type === "wifi") {
                    return (
                      <div
                        key={index}
                        className="flex items-center gap-2 p-3 rounded-lg border"
                      >
                        <Wifi className="h-4 w-4" />
                        <div>
                          <p className="font-medium">{action.ssid}</p>
                          {action.password && (
                            <p className="text-sm text-muted-foreground">
                              Password: {action.password}
                            </p>
                          )}
                          {action.encryption && (
                            <p className="text-sm text-muted-foreground">
                              Encryption: {action.encryption}
                            </p>
                          )}
                        </div>
                      </div>
                    );
                  }
                  return null;
                })}
              </div>
            </CardContent>
          </Card>
        )}

        {/* Footer */}
        <div className="text-center text-sm text-muted-foreground">
          <p>
            Last updated{" "}
            {formatDistanceToNow(new Date(note.updatedAt), { addSuffix: true })}
          </p>
        </div>
      </div>
    </div>
  );
}
