import { notFound, redirect } from "next/navigation";
import { headers } from "next/headers";
import { Metadata } from "next";
import { auth } from "@/auth";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  MapPin,
  Lock,
  Calendar,
  ExternalLink,
  Wifi,
  User,
  Mail,
  Phone,
  Building2,
  Briefcase,
  Globe,
  PlusCircle,
  MessageCircle,
  Share2,
  Wallet,
} from "lucide-react";
import { LocationDisplay } from "@/components/maps/location-display";
import { getNote } from "@/lib/actions/note-actions";
import { isEmailWhitelistedForNote } from "@/lib/actions/note-whitelist-actions";
import {
  signImageUrlsAction,
  signBusinessCardImage,
} from "@/lib/actions/s3-upload-actions";
import { formatDistanceToNow, format } from "date-fns";
import type { Action, BusinessCard, Address } from "@/lib/db/schema/notes";

function getWalletUri(network: string, address: string): string | null {
  const n = network.toLowerCase();
  if (["ethereum", "polygon", "base", "arbitrum"].includes(n)) {
    return `ethereum:${address}`;
  }
  if (n === "bitcoin") return `bitcoin:${address}`;
  if (n === "solana") return `solana:${address}`;
  if (n === "tron") return `tron:${address}`;
  if (n === "ton") return `ton://transfer/${address}`;
  return null;
}

interface PreviewPageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({
  params,
}: PreviewPageProps): Promise<Metadata> {
  const { id } = await params;
  const note = await getNote(id);

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

  const headersList = await headers();
  const accept = headersList.get("accept") || "";
  if (accept.includes("application/json")) {
    redirect(`/api/v1/notes/${id}`);
  }

  const note = await getNote(id);

  if (!note) {
    notFound();
  }

  // Check visibility
  if (note.visibility === "private") {
    const session = await auth();

    if (!session?.user) {
      redirect(`/login?callbackUrl=/preview/note/${id}`);
    }

    // Owner always has access
    if (note.userId !== session.user.id) {
      const hasAccess = session.user.email
        ? await isEmailWhitelistedForNote(id, session.user.email)
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
      redirect(`/login?callbackUrl=/preview/note/${id}`);
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
  const isBusinessCard = note.type === "business-card" && note.businessCard;

  // Sign business card profile image
  const businessCard = isBusinessCard
    ? await signBusinessCardImage(
        note.businessCard as BusinessCard & {
          imageUrl?: string | null;
          imageFileId?: number | null;
        }
      )
    : null;

  return (
    <div className="min-h-screen bg-muted/30 py-8">
      <div className="max-w-4xl mx-auto px-4">
        {/* Visibility badges */}
        <div className="flex items-center gap-2 mb-4">
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

        {isBusinessCard && businessCard ? (
          <>
            {/* Business Card Hero */}
            <Card className="mb-8 overflow-hidden">
              <CardContent className="pt-10 pb-8">
                <div className="flex flex-col items-center text-center">
                  {/* Profile Photo */}
                  {businessCard.imageUrl ? (
                    <img
                      src={businessCard.imageUrl}
                      alt={`${businessCard.firstName} ${businessCard.lastName}`}
                      className="w-24 h-24 rounded-full object-cover ring-4 ring-background shadow-lg mb-5"
                    />
                  ) : (
                    <div className="w-24 h-24 rounded-full bg-primary/10 flex items-center justify-center ring-4 ring-background shadow-lg mb-5">
                      <span className="text-3xl font-semibold text-primary">
                        {businessCard.firstName.charAt(0)}
                        {businessCard.lastName.charAt(0)}
                      </span>
                    </div>
                  )}

                  {/* Name */}
                  <h1 className="text-3xl font-bold tracking-tight">
                    {businessCard.firstName} {businessCard.lastName}
                  </h1>

                  {/* Title & Company */}
                  {(businessCard.jobTitle || businessCard.company) && (
                    <p className="mt-1.5 text-muted-foreground text-lg">
                      {[businessCard.jobTitle, businessCard.company]
                        .filter(Boolean)
                        .join(" · ")}
                    </p>
                  )}
                </div>
              </CardContent>
            </Card>

            {/* Contact Details */}
            {(businessCard.emails?.length ||
              businessCard.phones?.length ||
              businessCard.website ||
              businessCard.address) && (
              <Card className="mb-8">
                <CardContent className="p-0 divide-y">
                  {businessCard.emails?.map((entry, index) => (
                    <a
                      key={`email-${index}`}
                      href={`mailto:${entry.value}`}
                      className="flex items-center gap-4 px-6 py-4 hover:bg-accent/50 transition-colors"
                    >
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10">
                        <Mail className="h-5 w-5 text-primary" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs text-muted-foreground uppercase tracking-wide">
                          {entry.type}
                        </p>
                        <p className="text-sm font-medium truncate">
                          {entry.value}
                        </p>
                      </div>
                    </a>
                  ))}
                  {businessCard.phones?.map((entry, index) => (
                    <a
                      key={`phone-${index}`}
                      href={`tel:${entry.value}`}
                      className="flex items-center gap-4 px-6 py-4 hover:bg-accent/50 transition-colors"
                    >
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10">
                        <Phone className="h-5 w-5 text-primary" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs text-muted-foreground uppercase tracking-wide">
                          {entry.type}
                        </p>
                        <p className="text-sm font-medium truncate">
                          {entry.value}
                        </p>
                      </div>
                    </a>
                  ))}
                  {businessCard.website && (
                    <a
                      href={businessCard.website}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-4 px-6 py-4 hover:bg-accent/50 transition-colors"
                    >
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10">
                        <Globe className="h-5 w-5 text-primary" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs text-muted-foreground uppercase tracking-wide">
                          Website
                        </p>
                        <p className="text-sm font-medium truncate">
                          {businessCard.website}
                        </p>
                      </div>
                    </a>
                  )}
                  {businessCard.address && (businessCard.address.street || businessCard.address.city || businessCard.address.state || businessCard.address.zip || businessCard.address.country) && (
                    <div className="flex items-center gap-4 px-6 py-4">
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10">
                        <MapPin className="h-5 w-5 text-primary" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs text-muted-foreground uppercase tracking-wide">
                          Address
                        </p>
                        <p className="text-sm font-medium">
                          {[businessCard.address.street, businessCard.address.city, businessCard.address.state, businessCard.address.zip, businessCard.address.country]
                            .filter(Boolean)
                            .join(", ")}
                        </p>
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>
            )}

            {/* Social Profiles */}
            {businessCard.socialProfiles && businessCard.socialProfiles.length > 0 && (
              <Card className="mb-8">
                <CardContent className="p-0 divide-y">
                  {businessCard.socialProfiles.map((entry, index) => (
                    <div
                      key={`social-${index}`}
                      className="flex items-center gap-4 px-6 py-4"
                    >
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10">
                        <Share2 className="h-5 w-5 text-primary" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs text-muted-foreground uppercase tracking-wide">
                          {entry.name}
                        </p>
                        <p className="text-sm font-medium truncate">
                          {entry.value}
                        </p>
                      </div>
                    </div>
                  ))}
                </CardContent>
              </Card>
            )}

            {/* Instant Messaging */}
            {businessCard.instantMessaging && businessCard.instantMessaging.length > 0 && (
              <Card className="mb-8">
                <CardContent className="p-0 divide-y">
                  {businessCard.instantMessaging.map((entry, index) => (
                    <div
                      key={`im-${index}`}
                      className="flex items-center gap-4 px-6 py-4"
                    >
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10">
                        <MessageCircle className="h-5 w-5 text-primary" />
                      </div>
                      <div className="min-w-0">
                        <p className="text-xs text-muted-foreground uppercase tracking-wide">
                          {entry.name}
                        </p>
                        <p className="text-sm font-medium truncate">
                          {entry.value}
                        </p>
                      </div>
                    </div>
                  ))}
                </CardContent>
              </Card>
            )}

            {/* Wallets */}
            {businessCard.wallets && businessCard.wallets.length > 0 && (
              <Card className="mb-8">
                <CardContent className="p-0 divide-y">
                  {businessCard.wallets.map((entry, index) => {
                    const walletUri = getWalletUri(entry.name, entry.value);
                    const truncatedAddress = entry.value.length > 14
                      ? `${entry.value.slice(0, 6)}...${entry.value.slice(-4)}`
                      : entry.value;
                    const content = (
                      <>
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10">
                          <Wallet className="h-5 w-5 text-primary" />
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="text-xs text-muted-foreground uppercase tracking-wide">
                            {entry.name}
                          </p>
                          <p className="text-sm font-medium truncate font-mono">
                            {truncatedAddress}
                          </p>
                        </div>
                      </>
                    );
                    return walletUri ? (
                      <a
                        key={`wallet-${index}`}
                        href={walletUri}
                        className="flex items-center gap-4 px-6 py-4 hover:bg-accent/50 transition-colors"
                      >
                        {content}
                      </a>
                    ) : (
                      <div
                        key={`wallet-${index}`}
                        className="flex items-center gap-4 px-6 py-4"
                      >
                        {content}
                      </div>
                    );
                  })}
                </CardContent>
              </Card>
            )}
          </>
        ) : (
          <>
            {/* Regular Note Header */}
            <div className="mb-8">
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
          </>
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
                  if (action.type === "add-contact") {
                    return (
                      <div
                        key={index}
                        className="flex items-center gap-2 p-3 rounded-lg border"
                      >
                        <PlusCircle className="h-4 w-4" />
                        <div>
                          <p className="font-medium">
                            Add {action.firstName} {action.lastName} to Contacts
                          </p>
                          {action.company && (
                            <p className="text-sm text-muted-foreground">
                              {action.company}
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
