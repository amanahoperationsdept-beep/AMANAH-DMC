# Unilevel application — development notes

## Repository layout

The existing AMANAH-DMC landing page remains at the repository root. The Unilevel
application is being developed as a separate application area so that the
existing site is not overwritten.

## Agreed draft configuration

- Responsive web application with administrator and distributor accounts.
- PV conversion: 1 PV = PHP 1.
- Ten upline generations; differential commissions.
- Both personal PV and group PV are required for rank qualification.
- Rank percentages and thresholds in the starter migration are proposals only.
  They are not approved compensation terms and must be stress-tested and
  reviewed for Philippine direct-selling/MLM compliance before launch.

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

## Current implementation increment

Migration `0002_secure_monthly_closing.sql` is a follow-on migration for the starter schema in the previously generated ZIP. That `0001_initial_schema.sql` has not yet been imported into this repository, so **do not apply migration 0002 to a database yet**. Import and review the complete starter package first.

The migration:
- restricts monthly volume and commission draft RPCs to the Supabase
  `service_role`;
- refreshes monthly volume snapshots before building a draft commission run;
- prevents recalculation of approved or posted periods; and
- clears stale approval metadata when rebuilding a draft run.

## Known limitations / next work

1. This repository's existing `main` branch is a static landing page. The app
   foundation must be introduced in a separate directory and must not replace it.
2. The initial schema still needs a secure first-admin bootstrap and an admin
   approval workflow for pending distributor profiles.
3. Add server-side order creation, payment verification, immutable PV snapshots,
   and refund/reversal handling.
4. Add an explicit commission approval and idempotent wallet-posting workflow.
5. Add payout balance reservation, reconciliation, audit events, and automated
   database tests.
6. Verify all RLS policies and function grants against a real disposable
   Supabase project before production.
7. The starter SQL has not yet been applied to Supabase. No deployment or payout
   operation has been performed.

## Validation status

The migration has been statically reviewed against the starter schema. No live
PostgreSQL/Supabase instance is connected in this development session, so SQL
execution and integration tests remain pending.
