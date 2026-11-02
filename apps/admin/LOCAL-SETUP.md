# Run JTP on a laptop

This setup runs both web apps on localhost and uses the existing connected Supabase Cloud database. Changes made locally therefore affect the live database. It does not create a new project or reset/migrate any data.

## Requirements

Install Git and Node.js 24. Install the package manager matching package.json:

```sh
npm install -g pnpm@11.25.0
```

Use the bundled source ZIP, or clone https://github.com/prangya33crores-glitch/jtp.git. In GitHub, the folders are `apps/admin` and `apps/employee-portal`; in the supplied laptop ZIP they are `JTP-Admin` and `JTP-Employee-Portal`.

## Configure admin

Use `JTP-Admin/.dev.vars` from the laptop ZIP. The only missing value is `JTP_SUPABASE_LOCAL_SERVICE_KEY`. Open Supabase → JTP Management → Settings → API Keys and copy an existing server secret key (`sb_secret_...`), or the existing legacy `service_role` key. Paste it locally into that variable; do not paste it in chat or commit it. The publishable/anon key cannot run privileged server functions.

This project uses Cloudflare Worker bindings, so use `.dev.vars`, not a browser-facing `.env` file. These variables are never prefixed with `VITE_` or `NEXT_PUBLIC_`.

```dotenv
JTP_SUPABASE_URL="https://ruyjwiyuovgqdwfstevt.supabase.co"
JTP_SUPABASE_LOCAL_SERVICE_KEY="PASTE_YOUR_EXISTING_SERVER_KEY_HERE"
JTP_LOCAL_ADMIN_ID="wKOdYpAe99Ka9P0nQRaD0CRkqzHgYloLtoZ0rOGD0KqYR2XNajjMsB"
JTP_EMPLOYEE_BRIDGE="USE_THE_MATCHING_LOCAL_BRIDGE_FROM_THE_CONFIG_FILES"
```

Portable development loads .dev.vars before Vite starts. The local sign-in middleware supplies the configured workspace owner ID only for loopback requests with its local sign-in cookie. Start the development server on localhost. The direct Supabase server-key path is gated to Vite development builds; production continues to use the existing protected Edge Function.

In Terminal / PowerShell window 1:

```sh
cd JTP-Admin
pnpm install --frozen-lockfile
pnpm dev --port 5173
```

Open http://localhost:5173. The localhost sign-in redirect should establish the local development session; it does not require a ChatGPT login or an admin password. Use `pnpm dev`, not `pnpm start`, for this local workflow.

## Configure employee portal

The laptop ZIP includes `JTP-Employee-Portal/.dev.vars` pointing to the local admin backend. The bridge value matches the admin's local bridge. It is local configuration, not a production service credential.

```dotenv
JTP_BACKEND_URL="http://localhost:5173"
JTP_BACKEND_TOKEN="local-development"
JTP_EMPLOYEE_BRIDGE="USE_THE_MATCHING_LOCAL_BRIDGE_FROM_THE_CONFIG_FILES"
```

In Terminal / PowerShell window 2:

```sh
cd JTP-Employee-Portal
pnpm install --frozen-lockfile
pnpm dev --port 5174
```

Open http://localhost:5174. Use Employee ID/mobile and an existing employee password. For TEST001–TEST005, create their login credentials from the local Admin → Employee access screen first; test personnel records do not automatically create login accounts. Temporary passwords must be changed at first login.

## Troubleshooting

- Keep both terminal windows running and use `localhost` consistently.
- A 401/403 database error usually means the server key is missing, invalid or an anon/publishable key was supplied.
- If the admin redirects to the hosted employee portal, check JTP_LOCAL_ADMIN_ID and restart the dev server.
- Restart after changing .dev.vars.
- Do not run the schema files again against the existing connected project; the separate tables and functions are already installed.
- Never commit .dev.vars. Both application .gitignore files exclude it.
- Local-only credentials should not be used to deploy a public admin server. Public deployments retain the hosted authentication boundary.
