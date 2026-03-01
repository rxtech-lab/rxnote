import { redirect, notFound } from "next/navigation";

interface PreviewNotePageProps {
  searchParams: Promise<{ id?: string }>;
}

export default async function PreviewNotePage({ searchParams }: PreviewNotePageProps) {
  const { id } = await searchParams;

  if (!id) {
    notFound();
  }

  redirect(`/preview/note/${id}`);
}
