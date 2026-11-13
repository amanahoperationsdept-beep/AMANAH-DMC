# AMANAH Unilevel Supabase setup

Use ONLY this Supabase project for the new Unilevel application:

- Project URL: https://bqgxvnrgjmngezknqhsl.supabase.co
- Storage bucket created by migration: amanah-unilevel (private)

## Apply the database migration

1. Open the Supabase dashboard for project `bqgxvnrgjmngezknqhsl`.
2. Open SQL Editor.
3. Create a new query.
4. Copy and run the complete file:
   `supabase/migrations/202611130001_initial_unilevel.sql`
5. Check Table Editor for profiles, products, orders, order_items, commissions, wallets, withdrawal_requests, inventory and stock_movements.
6. Check Storage for the private `amanah-unilevel` bucket.

## Create the first administrator

1. Register your own account from the Unilevel app.
2. In Supabase Authentication > Users, copy that user's UUID.
3. In SQL Editor run, replacing the placeholder with the real UUID:

```sql
update public.profiles
set role = 'administrator'
where id = 'PASTE_AUTH_USER_UUID_HERE';
```

Never let public signup choose its own role. New signups are always distributors.

## Connect the frontend

Edit `unilevel/config.js` and replace the placeholder with the project's **publishable key** from Project Settings > API Keys. Do not use a secret key, service_role key, or database password in browser code.

## GitHub Pages

The workflow deploys the isolated application to:

https://amanahoperationsdept-beep.github.io/AMANAH-DMC/unilevel/

In GitHub, open Settings > Pages and select **GitHub Actions** as the build and deployment source if it is not already selected.

## Before production

The first migration is a secure foundation, not the finished business system. Do not process real commissions or payouts until the commission formula, order approval rules, inventory transactions, wallet ledger, and withdrawal release functions have been finalized and tested. The current unilevel commission percentages are deliberately not activated because the latest proposed rates still need final confirmation.
