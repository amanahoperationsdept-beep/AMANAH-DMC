# AMANAH DMC — Unilevel Network Management

AMANAH is being developed as a responsive network-management platform with separate administrator and distributor workspaces.

## Current application experience

- Public AMANAH landing page
- Separate Administrator and Distributor sign-in portals
- Role-specific dashboard previews
- Responsive desktop and mobile navigation
- Next.js App Router + TypeScript + Tailwind CSS
- Supabase client libraries included for the upcoming authentication and database integration

> **Important:** The sign-in and dashboard screens are currently an interface preview. They do not authenticate users or display live business data yet. Do not enter real passwords. The sample figures are illustrative only.

## Run locally

1. Install Node.js 20 or later.
2. Install dependencies: `npm install`
3. Copy `.env.example` to `.env.local` and add your Supabase project URL and anon key.
4. Start the app: `npm run dev`
5. Open `http://localhost:3000`

## Environment variables

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` — server-only; never expose this value in browser code.

## Planned system modules

- Secure Supabase Auth with role-based authorization
- Admin approval and distributor account onboarding
- Sponsor genealogy and member profiles
- Product catalog, PV assignment, orders and payment verification
- Monthly qualification and differential commissions
- Wallet ledger, payout requests, refund reversals and audit logs

## Compensation model — draft

The current planning model uses 1 PV = ₱1, up to 10 upline generations, and differential commissions based on qualified rank rates. Rank thresholds and rates remain draft settings and must be reviewed for financial sustainability and Philippine direct-selling compliance before launch.

Commissions must be tied to verified eligible product sales, not recruitment fees. Refunds and cancellations must reverse the corresponding PV and commissions.

## Database and deployment status

The database migrations are not yet ready to apply to a live Supabase project. The initial schema and secure monthly-closing migration must be reviewed and tested together in a disposable development database before any production deployment or payout workflow.

## Security principles

- All commission calculations and financial posting run on trusted server-side functions.
- Supabase Row Level Security protects member and financial records.
- Never expose the Supabase service-role key in client-side code.
- Require audit trails, idempotent posting, and approval controls for financial actions.
- No real payouts or production data changes until explicitly authorized and tested.
