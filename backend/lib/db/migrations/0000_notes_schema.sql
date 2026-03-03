CREATE TABLE `notes` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`user_id` text NOT NULL,
	`type` text DEFAULT 'regular-text-note' NOT NULL,
	`title` text NOT NULL,
	`note` text,
	`business_card` text DEFAULT null,
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
CREATE TABLE `note_whitelists` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`note_id` integer NOT NULL REFERENCES `notes`(`id`) ON DELETE CASCADE,
	`email` text NOT NULL,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `upload_files` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`user_id` text NOT NULL,
	`key` text NOT NULL,
	`filename` text NOT NULL,
	`content_type` text NOT NULL,
	`size` integer NOT NULL,
	`note_id` integer REFERENCES `notes`(`id`) ON DELETE SET NULL,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `account_deletions` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`user_id` text NOT NULL,
	`user_email` text,
	`scheduled_at` integer NOT NULL,
	`qstash_message_id` text,
	`status` text DEFAULT 'pending' NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
