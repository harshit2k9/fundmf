# Fundmf Website

The web companion to the Fundmf Android app. It talks to the **same Firebase
project** (`fundmf-mf`) and the **same Express backend** (`https://fundmf.onrender.com`),
so accounts, profiles, transactions and sync logs are shared across both clients.

## What it does

Investor

- Sign in / sign up / password reset with Firebase Auth
- Portfolio dashboard: invested, current value, absolute P&L, return %, CAGR
- Live AMFI NAVs from api.mfapi.in, average-cost scheme-wise holdings
- Allocation donut chart
- Transactions list with search, type filter, detail sheet and CSV export
- Profile: masked PAN, client ID, change password, APK download, sign out

Admin (`fundmfservices@gmail.com`)

- Client directory: provision, edit, approve/revoke and delete profiles
- Per-client portfolio valued by PAN
- CAMS sync trigger (`POST /api/cams/sync`) with the last 25 sync-log entries

## Responsive behaviour

| Viewport | Layout |
| --- | --- |
| Phone (`<= 767px`) | App-style UI: compact top bar, bottom navigation, card lists, and a **Download APK** button in the header, dashboard banner and profile page |
| Tablet / desktop (`>= 768px`) | Sidebar navigation, data tables, split dashboard (allocation + holdings) |

Both layouts expose the full feature set; the phone layout simply reorganises
the same data into native-app patterns and surfaces the APK download.

## Run locally

```bash
npm install
npm run copy-apk      # optional: copies ../build/app/outputs/flutter-apk/app-release.apk
npm run dev           # http://localhost:5173
```

`copy-apk` and `public/fundmf-release.apk` are gitignored — the APK is a build
artefact. To serve it from elsewhere, set `VITE_APK_URL` (see `.env.example`).

## Build and deploy

```bash
npm run build         # type-checks, then emits dist/
npm run deploy        # builds and runs firebase deploy --only hosting
```

`firebase.json` serves `dist/` with an SPA rewrite and the APK with the correct
`application/vnd.android.package-archive` content type. First deploy needs
`firebase login` and the `fundmf-mf` project selected.

### Firebase console checklist

1. **Authentication → Settings → Authorized domains**: add the hosting domain
   (`localhost` is allowed by default).
2. Email/password provider must be enabled (it already is for the Android app).
3. Firestore rules already allow an investor to read their own `users/{email}`
   document and `transactions` rows scoped to their PAN; the admin email keeps
   the broader access used by the directory and sync screens.

## Backend

The website calls `POST /api/cams/sync` with the admin's Firebase ID token. That
endpoint lives in `../server` and runs on Render; `ALLOWED_ORIGINS` defaults to
`*` with bearer-token auth. Set `VITE_API_BASE_URL` if you point the site at a
local server.

## Disclaimer

Every shell renders the footer: *Mutual Funds are subject to market risk. Invest wisely.*
