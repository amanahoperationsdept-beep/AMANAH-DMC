-- Seed the official AMANAH Distributor catalog.
-- Apply only to the new Unilevel Supabase project.
-- These are the two populated price columns supplied by the business.
insert into public.products (sku, name, srp, distributor_price, is_active)
values
  ('AMANAH-SPIRULINA', 'Spirulina', 350.00, 304.00, true),
  ('AMANAH-SERPENTINA', 'Serpentina', 600.00, 522.00, true),
  ('AMANAH-GLUTAGEN-CEE', 'Glutagen CEE', 600.00, 522.00, true),
  ('AMANAH-MAX-C-PRO', 'Max C Pro', 1000.00, 870.00, true),
  ('AMANAH-BASKUG', 'Baskug', 450.00, 391.00, true),
  ('AMANAH-BARAKAH', 'Barakah', 450.00, 391.00, true),
  ('AMANAH-HERBAL-OIL', 'Herbal Oil', 180.00, 156.00, true),
  ('AMANAH-HERBAL-RUB', 'Herbal Rub', 125.00, 108.00, true)
on conflict (sku) do update set
  name = excluded.name,
  srp = excluded.srp,
  distributor_price = excluded.distributor_price,
  is_active = excluded.is_active;
