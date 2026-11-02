# JTP Employee Portal

Separate mobile-friendly employee application using Employee ID/mobile and password. It has no ChatGPT account requirement.

Employees can view their published daily, upcoming, weekly and monthly duties, duty locations and shift leaders, leave records and approved/paid salary statements. The employee selector is never exposed; the private backend derives identity from an opaque session.

Admin creates, resets, enables and disables credentials in the original JTP Management application’s Employee access section. Temporary passwords must be changed on first login. Employees can change their password from the key icon. Forgot-password support is Admin reset.

## Architecture

This application has a public login page and a private cookie-authenticated API proxy. It does not store operational data locally. Its backend is the original private JTP site. Configure `JTP_BACKEND_URL`, `JTP_BACKEND_TOKEN`, and `JTP_EMPLOYEE_BRIDGE` as server secrets through Sites. The proxy forwards only fixed allowed operations and never sends the backend credentials to the browser. The proxy uses Secure HttpOnly SameSite=Strict cookies, strict Origin validation and no-store responses.

The private backend stores salted password hashes, session token hashes, credential bindings and attempt counters in D1. Session lifetime is 12 hours; password changes/reset and disabling revoke active sessions. Login throttling is 5 failures per normalized identifier and 50 requests per source IP per 15 minutes. Approved/Paid payroll only is visible.

Tests: `node --experimental-strip-types --test tests/proxy.test.mjs`. The original JTP repository contains database-backed authentication and authorization tests.

Use the Sites build/publish lifecycle. Keep the `sites()` integration and never commit runtime credentials. The login page must be publicly reachable for employees without ChatGPT accounts; employee records require password authentication. The original Super Admin site remains private.
