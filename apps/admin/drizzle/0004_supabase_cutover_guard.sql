CREATE TRIGGER freeze_workspaces_insert BEFORE INSERT ON workspaces WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_workspaces_update BEFORE UPDATE ON workspaces WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_workspaces_delete BEFORE DELETE ON workspaces WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_audit_insert BEFORE INSERT ON audit WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_audit_update BEFORE UPDATE ON audit WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_audit_delete BEFORE DELETE ON audit WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_employee_access_insert BEFORE INSERT ON employee_access WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_employee_access_update BEFORE UPDATE ON employee_access WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_employee_access_delete BEFORE DELETE ON employee_access WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_password_accounts_insert BEFORE INSERT ON password_accounts WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_password_accounts_update BEFORE UPDATE ON password_accounts WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_password_accounts_delete BEFORE DELETE ON password_accounts WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_password_sessions_insert BEFORE INSERT ON password_sessions WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_password_sessions_update BEFORE UPDATE ON password_sessions WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_password_sessions_delete BEFORE DELETE ON password_sessions WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_password_attempts_insert BEFORE INSERT ON password_attempts WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_password_attempts_update BEFORE UPDATE ON password_attempts WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;
--> statement-breakpoint
CREATE TRIGGER freeze_password_attempts_delete BEFORE DELETE ON password_attempts WHEN (SELECT value FROM portal_settings WHERE key='migration_lock')='locked' BEGIN SELECT RAISE(ABORT,'Database migration in progress. Please try again shortly.'); END;