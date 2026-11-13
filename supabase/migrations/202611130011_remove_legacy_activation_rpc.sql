-- Remove the obsolete one-argument activation-code RPC overload.
-- The current Edge Function calls the two-argument version so used_by is recorded.
begin;
drop function if exists public.consume_amanah_activation_code(text);
commit;
