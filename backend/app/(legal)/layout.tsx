import { ThemeToggle } from "@/components/theme-toggle";

export default function LegalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-background">
      <header className="mx-auto max-w-3xl px-6 pt-6 flex justify-end"></header>
      <main className="mx-auto max-w-3xl px-6 py-8">{children}</main>
    </div>
  );
}
