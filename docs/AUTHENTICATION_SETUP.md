# AMANAH authentication setup

## What this increment implements

- Email/password authentication through Supabase Auth.
- Server-managed Supabase session cookies, refreshed by Next.js middleware.
- Separate /admin and /distributor entry routes.
- Server-side role and account-status checks against the authenticated user's own
  public.profiles row.
- Sign-out through a server action.

The browser receives only the Supabase project URL and anon key. The service-role
key is not used by the authentication flow and must never be exposed to the browser.

## Required environment

Set these variables in the local server environment and deployment environment:

- NEXT_PUBLIC_SUPABASE_URL
- NEXT_PUBLIC_SUPABASE_ANON_KEY

Copy .env.example to .env.local for local development. Restart Next.js after
changing environment variables. Do not commit .env.local.

The database migrations must exist in a disposable development Supabase project
before profile-based sign-in can work. They have not been applied or verified by
this repository change.

## Account provisioning policy

Public self-registration is not enabled by this increment. A successful Supabase
password check is not enough to enter either workspace. The server also requires
a matching public.profiles row with status = 'active' and the exact portal role.

- Admin portal: profile role must be admin.
- Distributor portal: profile role must be distributor.
- Pending, suspended, closed, missing, or mismatched profiles are denied.
- A distributor cannot select the administrator portal to gain admin access.
- No client-side role value is trusted as authorization; it is checked against
  the database after Supabase Auth identifies the user.

## Controlled first-admin bootstrap for a development project

1. Create the first administrator user manually in the Supabase Auth dashboard.
   Do not expose a public admin-registration form.
2. Copy that Auth user's UUID from the dashboard.
3. In the development project's SQL Editor, insert the matching profile and
   self-genealogy row. Replace the placeholders with the exact Auth UUID and a
   unique member code:

       insert into public.profiles (id, member_code, full_name, role, status)
       values ('<AUTH_USER_UUID>', 'ADMIN-001', 'AMANAH Administrator', 'admin', 'active');

       insert into public.genealogy (ancestor_id, descendant_id, depth)
       values ('<AUTH_USER_UUID>', '<AUTH_USER_UUID>', 0);

4. Confirm the profile is active and the member code is unique before testing
   the admin portal.

Use the same controlled provisioning approach for test distributors, assigning
role = 'distributor' and initially status = 'pending'. An authorized admin
approval workflow is still to be implemented. Do not run this bootstrap against
a production project without explicit approval and a reviewed backup/recovery plan.

## Important limitations

- Password recovery, invitations, and distributor self-registration are not
  implemented yet.
- The workspace entry pages show only the authenticated profile identity; they
  do not query live business metrics.
- Admin bootstrap is a documented manual development procedure, not an
  application feature.
- RLS, migrations, and authentication still require integration testing against
  a disposable Supabase project before production use.
