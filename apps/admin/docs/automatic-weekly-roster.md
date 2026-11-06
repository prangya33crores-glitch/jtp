# Automatic weekly roster

The admin Duty roster opens on the current Asia/Kolkata period: 1–7, 8–14, 15–21, or 22–month end. Opening the current period automatically generates drafts once. Historical and future periods remain viewable, but the server rejects generation or publication outside the current period. A period becomes available at midnight IST on its first date.

Allocation retains each employee's most recent duty pattern from the previous published roster (or previous draft roster if none has been published), keeping active locations and leaders. It rotates to an eligible active shift and reuses the existing active-personnel, joining-date, overlap, overnight, approved-leave and consecutive-period shift checks. Without previous roster data it allocates active master personnel across active shifts and locations, with an active leader where available. No master data is created or changed by allocation.

The individual assignment form and month publication action are disabled. The admin reviews automatically generated drafts and selects **Publish period**. A retry of automatic allocation fills missing slots without replacing existing duties. Published periods are locked against regeneration; eligible leave covers can still be appended.

Approved leave creates cover with the same duty shift, location and leader, selecting a different available employee who passes the existing checks. If no eligible employee is available, uncovered duties are listed and publication is blocked. Leave approval after publication preserves the original duty and adds a separate cover for today or later in the current period. Cancelling that leave suppresses its cover and restores the original duty. Historical duties are retained. Attendance validates that a leave cover is still effective.

Supabase remains the source of truth. Workspace revision checks serialize conflicting saves, allocation slot keys and overlap checks prevent duplicate assignments, and normalized duty metadata is kept in `duty_assignments.attributes`. Allocation diagnostics are stored in `app_settings` under `rosterGeneration` and `rosterCoverage`.

Generation runs when an admin opens the current roster, or retries allocation; this change does not add an unattended cron job. Publishing requires the period-level admin action. Payroll, leave entitlements and master definitions are unchanged.

Validation: `node --experimental-strip-types --test tests/*.test.mjs` and `node node_modules/typescript/bin/tsc --noEmit`. `tests/weekly-roster-db.sql` verifies normalized saves, stale-revision rejection, metadata round trips and attendance cover validation inside a rolled-back transaction.
