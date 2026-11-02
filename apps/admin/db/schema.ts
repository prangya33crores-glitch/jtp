import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';
export const workspaces = sqliteTable('workspaces', { id: text('id').primaryKey(), revision: integer('revision').notNull().default(0), data: text('data').notNull() });
export const audit = sqliteTable('audit', { id: text('id').primaryKey(), workspace: text('workspace').notNull(), action: text('action').notNull(), details: text('details').notNull(), createdAt: text('created_at').notNull() });
export const portalSettings = sqliteTable('portal_settings', {key:text('key').primaryKey(),value:text('value').notNull()});
export const employeeAccess = sqliteTable('employee_access', {
 id:text('id').primaryKey(),workspace:text('workspace').notNull(),person:text('person').notNull(),
 codeHash:text('code_hash').unique(),expiresAt:text('expires_at'),userId:text('user_id').unique(),email:text('email'),
 status:text('status').notNull().default('Active'),createdAt:text('created_at').notNull()
});
export const passwordAccounts = sqliteTable('password_accounts',{id:text('id').primaryKey(),workspace:text('workspace').notNull(),person:text('person').notNull(),loginId:text('login_id').notNull().unique(),mobile:text('mobile').unique(),passwordHash:text('password_hash').notNull(),status:text('status').notNull().default('Active'),mustChange:integer('must_change').notNull().default(1),updatedAt:text('updated_at').notNull()});
export const passwordSessions = sqliteTable('password_sessions',{tokenHash:text('token_hash').primaryKey(),account:text('account').notNull(),credentialHash:text('credential_hash').notNull().default(''),expiresAt:text('expires_at').notNull()});
export const passwordAttempts = sqliteTable('password_attempts',{key:text('key').primaryKey(),count:integer('count').notNull(),resetAt:text('reset_at').notNull()});
