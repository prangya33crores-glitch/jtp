# JTP Command — Roster & Payroll

A private, database-backed JTP administration application built with React, TypeScript, Vinext and a Cloudflare D1 database.

## Working features

- Personnel, shifts, duty locations, shift leaders and leave policy masters; add, edit, search, status controls and CSV exports.
- Four dynamic monthly roster periods: 1–7, 8–14, 15–21 and 22–month end, including leap years.
- Bulk and daily duty assignment, draft/published states, table and calendar views, location filtering and print output.
- Weekly shift rotation restriction: a JTP cannot repeat the same shift in adjacent fixed roster periods, including month/year boundaries. Both draft and published assignments count; backdated entries and bulk ranges are checked, and publication revalidates existing records.
- Overnight overlap validation; approved leave prevents duties and clears conflicting assignments. Changes are audited.
- Leave entry, approvals, rejection/cancellation, paid/unpaid policy classification, half-day leave and entitlement checks per calendar month/year.
- Payroll generation, paid/unpaid leave calculation, actual-calendar or fixed-30 divisor, joining-date proration, draft/approved/paid transitions and printable salary slips.
- Immutable finalized payroll and protected leave periods. Regenerating payroll updates draft records only.
- Monthly leave, salary, deployment and leave balance reports, CSV export and browser print-to-PDF.
- Durable owner-scoped server storage with optimistic concurrency and transactional data/audit saves. UI shows latest 500 actions; the database retains before/after audit snapshots.
- Responsive interface, private ChatGPT sign-in and IST dates.
- Employee access management: 7-day single-use codes (SHA-256 hashes in storage), account linking, reset/revocation and disable/enable controls.
- `/employee` portal shows only the authenticated employee’s name, JTP ID, approved leave and published schedule. Super Admin APIs and the root admin page enforce the original owner identity. Employee requests cannot select another JTP ID or access payroll.

## First setup

1. Add shifts, locations, shift leaders and leave policies under Master Management.
2. Add personnel with joining dates and monthly salaries.
3. Select the month and roster period; assign duties and publish the month.
4. Enter leave requests and approve when appropriate. Affected duties are removed; assign replacements manually.
5. Generate salary, review slips, approve, and mark paid after payment has actually been made externally. This app does not initiate bank payments.

## Scope and differences from the supplied production specification

The deployed version uses hosted D1 and ChatGPT owner sign-in, rather than Supabase/PostgreSQL and Supabase Auth. It has one Super Admin workspace and employee self-service accounts linked to JTP IDs using single-use codes and dispatch-owned ChatGPT identity. Optional Admin/Shift Leader roles are not implemented. Employee portal access also requires the owner to add the employee as a site Viewer in Sites access settings; the app does not send invitations. CSV and print-to-PDF exports are supported; XLSX import/export, photo uploads, Aadhaar handling, carry-forward/accrual policies, effective-dated policy revisions, employee categories, salary adjustments, weekly offs, coverage warnings, sorting/pagination, a separate permanent address and per-person history views are not implemented. These require a further implementation phase before the full production specification is satisfied. Draft recalculation uses the current personnel salary; finalized payroll retains the rate it used. Entitlements apply immediately per calendar month/year without joining-date leave proration. Half-day leave blocks a full duty day conservatively. Cancelling leave does not restore removed duties automatically.

## Development

Dependencies are managed by the Sites lifecycle helpers. Preserve the `sites()` Vite integration and `.openai/hosting.json`.

- Typecheck: `node node_modules/typescript/bin/tsc --noEmit`
- Business-rule checks: `node --experimental-strip-types --test tests/engine.test.mjs`
- Schema generation: `npm run db:generate`
- Build: use the Sites `scripts/build-site.mjs` helper.

For local D1 migrations, first build, then run the generated schema migration with Wrangler `d1 execute DB --local --config dist/server/wrangler.json --persist-to .wrangler/state --file <migration>`. Hosted migrations are applied by deployment. The private production gateway supplies authenticated identity headers; managed preview has no mock identity, so authenticated save flows cannot be verified through its anonymous browser session. All API operations reject anonymous requests. The pure business rules are covered by 16 automated tests.

## Employee access workflow

1. Open Employee access as Super Admin. Select a JTP and generate a one-time code.
2. In the Site Share/access settings, add the employee’s ChatGPT email as a Viewer, keeping the site private. Do not grant Editor access.
3. Privately share the portal URL (`/employee`) and code. No email/message is sent by this app.
4. Employee signs in with their own ChatGPT account, enters the code once, and sees only their own published duties. Codes expire after 7 days. Super Admin cannot claim an employee code.
5. Admin assigns and publishes duty; employee refreshes the portal to see changes.
6. Disable access to block reads immediately. Reset access to unlink the old identity and issue a fresh code. Inactivating the personnel record also blocks access.

The migration adds `portal_settings` and `employee_access` without modifying historical data. On upgrade, the Super Admin identity is fixed from the sole existing owner workspace, never from a new visitor. Missing or ambiguous owner state fails closed. The route-level tests use an isolated in-memory SQLite database and mocked platform identities; they never use production credentials. A real employee onboarding smoke test requires a separate ChatGPT account invited by the owner.

## Password-based Employee Portal

The separate employee application is hosted at https://jtp-employee-portal.awakepixie1024.chatgpt.site and uses Employee ID/mobile and password login. Super Admin remains behind ChatGPT authentication on the original private site. The Employee access page now manages password credentials; previous code-based onboarding is no longer the primary flow.

Admin selects a JTP, sets or generates a temporary password, saves credentials and privately shares them with the employee. No invitation or ChatGPT account is required for the separate employee portal. First login forces password change. Password reset, disabled account and inactive personnel block existing sessions. Passwords are salted PBKDF2-SHA256 hashes; opaque session tokens are hashed in the database, bound to the current credential, and expire after 12 hours. Login attempts are limited by normalized login and source IP. The portal uses Secure, HttpOnly, SameSite=Strict cookies with strict Origin checks.

The public portal is a server-side proxy to `/api/staff-service` on the private backend. The private backend requires a platform service credential plus an environment-bound bridge secret. Browser code receives neither. Configure runtime secrets through Sites: backend `JTP_EMPLOYEE_BRIDGE`; employee app `JTP_BACKEND_URL`, `JTP_BACKEND_TOKEN`, `JTP_EMPLOYEE_BRIDGE`. The platform service token is used for both the dispatch header and bridge check; if it is rotated, update both sites and redeploy. Never put service credentials in source, client code or URLs.

Employee data is projected from the session’s linked person ID on every request; arbitrary person parameters are ignored. Duties must be published, salary records must be Approved/Paid, and all leave statuses are limited to that employee. Payroll drafts and other employee data are not returned. Admin login ID/mobile snapshots are synchronized when credentials are saved/reset. Forgotten passwords are reset by Admin; there is no automated SMS/email reset service.

## Supabase Cloud database (current production)

The production database is Supabase PostgreSQL, project `ruyjwiyuovgqdwfstevt`, Mumbai (`ap-south-1`). Both applications continue using their existing URLs. The employee portal reads through the admin server; it has no database keys and never receives other employees' records.

Admin requests use the existing Sites identity checks. Employee login keeps the existing salted PBKDF2 password hashes, forced temporary-password change, server sessions, throttling and account checks. This migration does not convert accounts to Supabase Auth. Passwords and employee IDs/mobile numbers remain valid.

The server calls `supabase/functions/jtp-database` using runtime secret keys `JTP_SUPABASE_URL` and `JTP_SUPABASE_SECRET`. Deploy the function with its SHA-256 key verifier configured for the runtime secret; the raw secret must never be committed. The function uses Supabase's automatically provided `SUPABASE_SERVICE_ROLE_KEY` only on the server. All tables have RLS enabled and no browser grants. Only `service_role` may run `jtp_batch`; it accepts an exact server-query allowlist and quotes parameter values as literals. Batches run in one PostgreSQL transaction, preserving revision checks, audit writes and reset/session changes.

Schema and operation registry: `supabase/schema/initial.sql`. After importing the source and verifying all seven tables, run `supabase/schema/complete-cutover.sql` to remove bulk import/export access. The original D1 database is an immutable backup, write-locked by `0004_supabase_cutover_guard.sql`; production application code does not read or write D1.

Verified transfer: 180 personnel, 3 shifts, 1 location, 3 leaders, 1 leave policy, 20 duty assignments, 14 audit entries, 1 password account, 1 legacy access account, and session/throttling/settings rows. Leave and payroll tables in the workspace were empty. All seven source tables matched SHA-256 checks after import, including JSON state and password hashes.

Health: `/api/database-health` returns only readiness and database provider, never records.
