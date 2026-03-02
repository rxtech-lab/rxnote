export default function LegalLoading() {
  return (
    <div className="animate-pulse space-y-6">
      {/* Title */}
      <div className="h-9 w-48 rounded-md bg-muted" />

      {/* Subtitle / date */}
      <div className="h-4 w-64 rounded bg-muted" />

      {/* Paragraph block */}
      <div className="space-y-2.5">
        <div className="h-4 w-full rounded bg-muted" />
        <div className="h-4 w-full rounded bg-muted" />
        <div className="h-4 w-3/4 rounded bg-muted" />
      </div>

      {/* Section heading */}
      <div className="h-7 w-56 rounded-md bg-muted" />

      {/* Paragraph block */}
      <div className="space-y-2.5">
        <div className="h-4 w-full rounded bg-muted" />
        <div className="h-4 w-full rounded bg-muted" />
        <div className="h-4 w-5/6 rounded bg-muted" />
      </div>

      {/* Sub-heading */}
      <div className="h-5 w-40 rounded bg-muted" />

      {/* List items */}
      <div className="space-y-3 pl-4">
        <div className="flex gap-2">
          <div className="h-4 w-4 shrink-0 rounded-full bg-muted" />
          <div className="h-4 w-full rounded bg-muted" />
        </div>
        <div className="flex gap-2">
          <div className="h-4 w-4 shrink-0 rounded-full bg-muted" />
          <div className="h-4 w-5/6 rounded bg-muted" />
        </div>
        <div className="flex gap-2">
          <div className="h-4 w-4 shrink-0 rounded-full bg-muted" />
          <div className="h-4 w-2/3 rounded bg-muted" />
        </div>
      </div>

      {/* Section heading */}
      <div className="h-7 w-44 rounded-md bg-muted" />

      {/* Paragraph block */}
      <div className="space-y-2.5">
        <div className="h-4 w-full rounded bg-muted" />
        <div className="h-4 w-full rounded bg-muted" />
        <div className="h-4 w-2/3 rounded bg-muted" />
      </div>
    </div>
  );
}
