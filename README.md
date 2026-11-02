# JTP Roster & Salary Management

Both JTP web applications with Supabase Cloud database integration.

| Folder | Application |
| --- | --- |
| `apps/admin` | Personnel, duty roster, leave, salaries and employee login management |
| `apps/employee-portal` | Employee ID/mobile and password portal showing each employee's own records |

See each application's README for setup, runtime variables, tests and hosting requirements. The admin application's `supabase` directory includes the PostgreSQL schema and database Edge Function source.

The existing employee authentication is preserved; Supabase PostgreSQL stores the records. No production records or runtime credentials are included.

This repository contains source code. Pushing code does not automatically deploy the hosted Sites.
