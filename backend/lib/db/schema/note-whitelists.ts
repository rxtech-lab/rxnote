import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";
import { notes } from "./notes";

export const noteWhitelists = sqliteTable("note_whitelists", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  noteId: text("note_id")
    .notNull()
    .references(() => notes.id, { onDelete: "cascade" }),
  email: text("email").notNull(),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export const noteWhitelistsRelations = relations(noteWhitelists, ({ one }) => ({
  note: one(notes, {
    fields: [noteWhitelists.noteId],
    references: [notes.id],
  }),
}));

export type NoteWhitelist = typeof noteWhitelists.$inferSelect;
export type NewNoteWhitelist = typeof noteWhitelists.$inferInsert;
