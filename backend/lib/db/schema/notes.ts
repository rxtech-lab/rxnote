import { sqliteTable, text, integer, real } from "drizzle-orm/sqlite-core";

export const notes = sqliteTable("notes", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  userId: text("user_id").notNull(),
  type: text("type", { enum: ["regular-text-note"] })
    .notNull()
    .default("regular-text-note"),
  title: text("title").notNull(),
  note: text("note"),
  images: text("images", { mode: "json" }).$type<string[]>().default([]),
  audios: text("audios", { mode: "json" }).$type<string[]>().default([]),
  videos: text("videos", { mode: "json" }).$type<string[]>().default([]),
  latitude: real("latitude"),
  longitude: real("longitude"),
  actions: text("actions", { mode: "json" })
    .$type<Action[]>()
    .default([]),
  visibility: text("visibility", {
    enum: ["public", "private", "auth-only"],
  })
    .notNull()
    .default("private"),
  createdAt: integer("created_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" })
    .notNull()
    .$defaultFn(() => new Date()),
});

export interface URLAction {
  type: "url";
  label: string;
  url: string;
}

export interface WifiAction {
  type: "wifi";
  ssid: string;
  password?: string;
  encryption?: "WPA" | "WEP" | "none";
}

export type Action = URLAction | WifiAction;

export type Note = typeof notes.$inferSelect;
export type NewNote = typeof notes.$inferInsert;
