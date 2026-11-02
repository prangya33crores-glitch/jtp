CREATE TABLE `employee_access` (
	`id` text PRIMARY KEY NOT NULL,
	`workspace` text NOT NULL,
	`person` text NOT NULL,
	`code_hash` text,
	`expires_at` text,
	`user_id` text,
	`email` text,
	`status` text DEFAULT 'Active' NOT NULL,
	`created_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `employee_access_code_hash_unique` ON `employee_access` (`code_hash`);--> statement-breakpoint
CREATE UNIQUE INDEX `employee_access_user_id_unique` ON `employee_access` (`user_id`);--> statement-breakpoint
CREATE TABLE `portal_settings` (
	`key` text PRIMARY KEY NOT NULL,
	`value` text NOT NULL
);
