CREATE TABLE `password_accounts` (
	`id` text PRIMARY KEY NOT NULL,
	`workspace` text NOT NULL,
	`person` text NOT NULL,
	`login_id` text NOT NULL,
	`mobile` text,
	`password_hash` text NOT NULL,
	`status` text DEFAULT 'Active' NOT NULL,
	`must_change` integer DEFAULT 1 NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `password_accounts_login_id_unique` ON `password_accounts` (`login_id`);--> statement-breakpoint
CREATE UNIQUE INDEX `password_accounts_mobile_unique` ON `password_accounts` (`mobile`);--> statement-breakpoint
CREATE TABLE `password_attempts` (
	`key` text PRIMARY KEY NOT NULL,
	`count` integer NOT NULL,
	`reset_at` text NOT NULL
);
--> statement-breakpoint
CREATE TABLE `password_sessions` (
	`token_hash` text PRIMARY KEY NOT NULL,
	`account` text NOT NULL,
	`expires_at` text NOT NULL
);
