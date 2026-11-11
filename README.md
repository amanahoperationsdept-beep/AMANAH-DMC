# AMANAH DMC — Unilevel Network Management

AMANAH is being developed as a responsive network-management platform with separate administrator and distributor workspaces.

## Current application experience

- Public AMANAH landing page and responsive product catalog.
- Supabase email/password sign-in integration.
- Separate server-guarded Administrator and Distributor workspace routes.
- Server-side checks for authenticated profile role and active account status.
- A clearly labelled sample dashboard preview; its figures are not live records.
- Next.js App Router, TypeScript, Tailwind CSS, and Supabase SSR.

> **Important:** Authentication code is in place but still requires Supabase environment configuration, database migrations, and provisioned profile records. The new workspace entry pages verify identity and role; operational modules and live business data are not connected. Do not use the sample dashboard figures for business decisions.

## Run locally

1. Install Node.js 20 or later.
2. Install dependencies: `npm install`.
3. Copy `.env.example` to `.env.local` and add your Supabase project URL and anon key.
4. Start the app: `npm run dev`.
5. Open `http://localhost:3000`.

## Environment variables

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` — reserved for future trusted server operations; never expose it to browser code. It is not required for sign-in.

See [Supabase authentication setup](docs/AUTHENTICATION_SETUP.md) for account provisioning and the controlled development-only first-admin bootstrap.

## Planned system modules

- Admin approval and distributor account onboarding.
- Sponsor genealogy and member profiles.
- Product catalog administration, immutable order/PV snapshots, and payment verification.
- Digital stock locations, transfers, and scoped finance approval.
- Monthly qualification and differential commissions.
- Commission approval, immutable wallet ledger, payout safeguards, refund reversals, and audit logs.

## Compensation model — draft

The current planning model uses 1 PV = ₱1, up to 10 upline generations, and differential commissions based on qualified rank rates. Rank thresholds and rates remain draft settings and must be reviewed for financial sustainability and Philippine direct-selling compliance before launch.

Commissions must be tied to verified eligible product sales, not recruitment fees. Refunds and cancellations must reverse the corresponding PV and commissions.

## Database and deployment status

The initial schema and secure monthly-closing migration have not been applied or integration-tested against the supplied Supabase project. Review and test them together in a disposable development database before any production deployment or payout workflow.

## Security principles

- Authentication and role checks run server-side; a selected portal is never treated as proof of authorization.
- Supabase Row Level Security protects member and financial records.
- Never expose the Supabase service-role key in client-side code.
- Require audit trails, idempotent posting, and approval controls for financial actions.
- No real payouts or production data changes until explicitly authorized and tested.
