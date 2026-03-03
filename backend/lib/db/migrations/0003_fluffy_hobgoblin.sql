PRAGMA foreign_keys=OFF;--> statement-breakpoint
CREATE TABLE `__new_note_whitelists` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`note_id` text NOT NULL,
	`email` text NOT NULL,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`note_id`) REFERENCES `notes`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
INSERT INTO `__new_note_whitelists`("id", "note_id", "email", "created_at") SELECT "id", "note_id", "email", "created_at" FROM `note_whitelists`;--> statement-breakpoint
DROP TABLE `note_whitelists`;--> statement-breakpoint
ALTER TABLE `__new_note_whitelists` RENAME TO `note_whitelists`;--> statement-breakpoint
PRAGMA foreign_keys=ON;--> statement-breakpoint
CREATE TABLE `__new_notes` (
	`id` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`type` text DEFAULT 'regular-text-note' NOT NULL,
	`title` text NOT NULL,
	`note` text,
	`business_card` text DEFAULT 'null',
	`images` text DEFAULT '[]',
	`audios` text DEFAULT '[]',
	`videos` text DEFAULT '[]',
	`latitude` real,
	`longitude` real,
	`actions` text DEFAULT '[]',
	`visibility` text DEFAULT 'private' NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
--> statement-breakpoint
INSERT INTO `__new_notes`("id", "user_id", "type", "title", "note", "business_card", "images", "audios", "videos", "latitude", "longitude", "actions", "visibility", "created_at", "updated_at") SELECT "id", "user_id", "type", "title", "note", "business_card", "images", "audios", "videos", "latitude", "longitude", "actions", "visibility", "created_at", "updated_at" FROM `notes`;--> statement-breakpoint
DROP TABLE `notes`;--> statement-breakpoint
ALTER TABLE `__new_notes` RENAME TO `notes`;--> statement-breakpoint
CREATE TABLE `__new_upload_files` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`user_id` text NOT NULL,
	`key` text NOT NULL,
	`filename` text NOT NULL,
	`content_type` text NOT NULL,
	`size` integer NOT NULL,
	`note_id` text,
	`created_at` integer NOT NULL,
	FOREIGN KEY (`note_id`) REFERENCES `notes`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
INSERT INTO `__new_upload_files`("id", "user_id", "key", "filename", "content_type", "size", "note_id", "created_at") SELECT "id", "user_id", "key", "filename", "content_type", "size", "note_id", "created_at" FROM `upload_files`;--> statement-breakpoint
DROP TABLE `upload_files`;--> statement-breakpoint
ALTER TABLE `__new_upload_files` RENAME TO `upload_files`;