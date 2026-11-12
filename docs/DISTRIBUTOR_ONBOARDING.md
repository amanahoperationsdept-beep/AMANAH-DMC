# AMANAH distributor onboarding and approval

## Workflow

1. A prospective distributor opens the public distributor registration page.
2. They provide their name, email, optional phone number, password, and an active distributor sponsor code.
3. Supabase Auth creates the user. The database trigger creates a pending distributor profile and closure-table genealogy rows in the same transaction.
4. The applicant verifies their email through the Supabase confirmation link.
5. An active administrator reviews the pending application in the Admin workspace.
6. Approval changes the profile from pending to active. Rejection closes the profile. Both decisions create an append-only review event.
7. Only active distributor profiles can sign in to the Distributor workspace.

Administrator accounts are never created through public registration. The first/root distributor must be provisioned by an administrator using a controlled development procedure.

## Database migration

Apply the migrations in order in a disposable development Supabase project:

1. supabase/migrations/0001_initial_schema.sql
2. supabase/migrations/0002_secure_monthly_closing.sql
3. supabase/migrations/0003_distributor_onboarding.sql

Migration 0003 adds an append-only member review event table, minimal sponsor-code lookup, Auth-triggered pending distributor creation, generated member codes, atomic genealogy rows, and an admin-only review function. It also revokes the older client-callable register_member RPC so clients cannot choose a member code or sponsor UUID.

A rejected application is stored with profile status closed; the review event records the explicit rejected decision. This avoids changing the existing member_status enum in a potentially transaction-sensitive migration.

## Supabase Auth configuration

Set NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, and NEXT_PUBLIC_SITE_URL. NEXT_PUBLIC_SITE_URL is the canonical origin, for example http://localhost:3000 in local development. Configure Supabase Auth URL settings so the allowed redirect list includes the origin plus /auth/callback for each environment.

Email confirmation should remain enabled where possible. The database approval function independently checks auth.users.email_confirmed_at before activating an applicant.

## Security properties

- The browser never supplies a role, member status, generated member code, or sponsor UUID.
- Sponsor codes are revalidated inside the Auth trigger while the sponsor row is locked.
- Invalid, inactive, non-distributor, or missing sponsor codes cause the Auth/profile transaction to fail.
- The Auth trigger only handles users explicitly marked as AMANAH distributor signups; manually provisioned administrators are untouched.
- Every new distributor begins pending and has no access to protected distributor pages until an administrator approves them.
- Review decisions are checked again inside a SECURITY DEFINER database function. Hiding buttons is not authorization.
- The reviewer cannot approve their own account.
- Review history is readable by the applicant and active administrators, but clients have no insert/update/delete privileges.
- Repeated approval/rejection attempts fail because only pending distributor profiles can be reviewed.
- Approval does not create PV, sales, commissions, wallet credits, or payouts.

## Testing checklist for a disposable Supabase project

- Apply all three migrations in order.
- Confirm a normal manually created admin Auth user is not automatically assigned a distributor profile.
- Sign up with a valid active distributor sponsor code; confirm profile status is pending, role is distributor, and genealogy contains one self row plus the sponsor's ancestors.
- Try an invalid, suspended, admin, and missing sponsor code; confirm signup/profile creation fails.
- Confirm a generated member code is assigned and cannot be selected by the browser.
- Confirm a new applicant cannot access /distributor before approval.
- Attempt approval before email confirmation; confirm the database rejects it.
- Confirm a non-admin cannot review an application.
- Confirm an active admin can approve a verified applicant and the profile becomes active.
- Confirm an active admin can reject a pending applicant and the profile becomes closed with a rejected review event.
- Confirm the same application cannot be reviewed twice.
- Confirm a distributor can read only their own review events and cannot write review events.
- Confirm no approval path creates financial records.

## Limitations

The migration and application code are committed for review but have not been applied to the supplied Supabase project. The SQL behavior, Auth email template/redirect settings, and end-to-end flows must be tested in a disposable project before production. This increment does not implement distributor profile editing, sponsor reassignment, password recovery, or financial operations.
