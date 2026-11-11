# AMANAH Unilevel application — development notes

## Repository layout

The root repository is now the Next.js application. The previous static `index.html`
landing page has been removed from this feature branch and replaced by the
Next.js App Router experience under `src/app`.

## Current interface increment

- New AMANAH public landing page and brand styling.
- Separate Administrator and Distributor sign-in portals.
- Role-specific dashboard previews and navigation.
- Responsive desktop and mobile layouts.
- Supabase Auth and database client libraries included as dependencies.

**Authentication is not connected yet.** The login screen is a UI preview only;
it does not validate credentials or establish a session. Dashboard values and
activity are sample data. Do not enter real passwords or use these sample figures
for business decisions.

## Agreed draft configuration

- Responsive web application with administrator and distributor accounts.
- PV conversion: 1 PV = PHP 1.
- Ten upline generations; differential commissions.
- Both personal PV and group PV are required for rank qualification.
- Rank percentages and thresholds in the initial migration are proposals only.
  They are not approved compensation terms and must be stress-tested and
  reviewed for Philippine direct-selling/MLM compliance before launch.

## Database migration sequence

1. `supabase/migrations/0001_initial_schema.sql` — imported initial schema.
2. `supabase/migrations/0002_secure_monthly_closing.sql` — restricts monthly
   calculation RPCs to service-role execution and adds closing safeguards.

The migrations have **not** been applied to any Supabase project. They must be
reviewed and tested together in a disposable development database first.

## Security baseline

- Commission and monthly closing calculations run only through trusted
  server-side code using the Supabase service-role credential.
- The service-role credential must never be exposed to a browser.
- Client access is governed by Supabase Auth and row-level security.
- Product name, price and PV must be snapshotted on each order item.
- Commission calculations must use verified paid orders and immutable ledger
  records. Refunds/cancellations need an explicit reversal workflow.
- Approved/posted monthly periods must not be recalculated.
- Real payouts and production database changes require separate explicit approval.

## Next implementation priorities

1. Connect Supabase Auth with server-side session handling and role guards.
2. Implement a safe first-admin bootstrap; never allow public self-registration
   to grant an admin role.
3. Add pending distributor approval and sponsor/genealogy validation.
4. Add server-side order creation, payment verification, immutable PV snapshots,
   and refund/reversal handling.
5. Add an explicit commission approval and idempotent wallet-posting workflow.
6. Add payout balance reservation, reconciliation, audit events, and automated
   database tests.
7. Replace dashboard sample data with RLS-protected live queries.
8. Verify all RLS policies and function grants against a real disposable
   Supabase project before production.

## Validation status

The repository now contains the initial schema and secure monthly-closing
migration, plus the first UI increment. No live PostgreSQL/Supabase instance is
connected in this development session. SQL execution, application build,
authentication integration, and end-to-end tests remain pending. No production
deployment or payout operation has been performed.
