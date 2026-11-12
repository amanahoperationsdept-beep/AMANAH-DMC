# AMANAH Unilevel application — development notes

## Repository layout

The root repository is the Next.js application. The previous static landing page
has been replaced on this feature branch by the Next.js App Router experience
under src/app.

## Current interface and authentication increment

- AMANAH public landing page, brand styling, and responsive product catalog.
- Supabase email/password sign-in action.
- Server-managed Supabase session cookies refreshed by root middleware.
- Separate /admin and /distributor routes with server-side active-profile role guards.
- Sign-out server action.
- Public distributor application with sponsor-code validation and generated member codes.
- Supabase Auth confirmation callback; pending accounts are signed out until approved.
- Admin-only distributor approval/rejection queue with database-enforced review checks and append-only review events.
- Sample dashboard preview remains illustrative and is not used as authenticated data.

Authentication integration code is present, but it has not been connected to or
tested against the user's live Supabase project. The app requires the project URL,
anon key, the reviewed database schema, and provisioned profile rows. Only active
profiles with the matching database role can enter the corresponding workspace.
Distributor registration and administrator review code are implemented on this branch, but require migration 0003 and disposable-project integration testing before use.

## Authentication setup

See docs/AUTHENTICATION_SETUP.md for environment variables, account provisioning,
and the controlled development-only first-admin bootstrap. No service-role key
is used by the sign-in flow.

## Agreed draft configuration

- Responsive web application with administrator and distributor accounts.
- PV conversion: 1 PV = PHP 1.
- Ten upline generations; differential commissions.
- Both personal PV and group PV are required for rank qualification.
- Rank percentages and thresholds in the initial migration are proposals only.
  They are not approved compensation terms and must be stress-tested and
  reviewed for Philippine direct-selling/MLM compliance before launch.

## Digital stock and payment verification design

The confirmed workflow and authorization policy are documented in
docs/DIGITAL_STOCK_PAYMENT_VERIFICATION.md:

- Main AMANAH, Branch Operators, and Mobile Stockists may initiate payment
  verification only when they have sufficient available digital stock.
- Separate, individually authorized finance users at all three operating
  levels may review and approve/reject within their assigned scope.
- Initiators cannot approve their own requests.
- Stock reservation, payment approval, inventory finalization, and PV posting
  must be secure, auditable, and idempotent.

This is a design specification only. The stock hierarchy, finance permission
scopes, payment verification, and PV ledger are not implemented in the current
schema.

## Database migration sequence

1. supabase/migrations/0001_initial_schema.sql — initial schema.
2. supabase/migrations/0002_secure_monthly_closing.sql — restricts monthly
   calculation RPCs to service-role execution and adds closing safeguards.
3. supabase/migrations/0003_distributor_onboarding.sql — creates pending distributor
   profiles from Auth signups and adds database-enforced admin review.

The migrations have not been applied to any Supabase project. They must be
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

1. Test distributor signup, email confirmation, sponsor genealogy, and admin
   approval in a disposable Supabase project; retain a controlled first-admin
   bootstrap and no public admin self-registration.
2. Implement the digital stock, organization hierarchy, stock transfer, and
   location-scoped finance permission design.
3. Add server-side order creation, payment verification, immutable PV snapshots,
   and refund/reversal handling.
4. Add an explicit commission approval and idempotent wallet-posting workflow.
5. Add payout balance reservation, reconciliation, audit events, and automated
   database tests.
6. Replace dashboard sample data with RLS-protected live queries.
7. Verify all RLS policies and function grants against a real disposable
   Supabase project before production.

## Validation status

The repository now contains the Supabase Auth integration code and a GitHub
Actions validation workflow for lint, TypeScript, and production build checks.
No live Supabase project is connected. Authentication, all three migrations,
email confirmation, sponsor genealogy, and approval behavior still require
disposable-project integration testing.
No production deployment, payout, or production data change has been performed.
