
-- Add a flag for the top "contact us" tier (no Stripe price; no checkout)
alter table public.subscription_tiers
  add column if not exists is_contact_only boolean not null default false;

-- Update the 6 tiers with new ranges, prices, and display names.
-- Slugs (id) stay stable so any existing references keep working.
update public.subscription_tiers set
  name = 'YGTeeV 1', range_label = '1—19',     max_active = 19,    price_cents = 2900,
  is_contact_only = false, stripe_price_id = null
where id = 'starter';

update public.subscription_tiers set
  name = 'YGTeeV 2', range_label = '20—49',    max_active = 49,    price_cents = 5900,
  is_contact_only = false, stripe_price_id = null
where id = 'growing';

update public.subscription_tiers set
  name = 'YGTeeV 3', range_label = '50—99',    max_active = 99,    price_cents = 11900,
  is_contact_only = false, stripe_price_id = null
where id = 'established';

update public.subscription_tiers set
  name = 'YGTeeV 4', range_label = '100—199',  max_active = 199,   price_cents = 16900,
  is_contact_only = false, stripe_price_id = null
where id = 'big';

update public.subscription_tiers set
  name = 'YGTeeV 5', range_label = '200—499',  max_active = 499,   price_cents = 27900,
  is_contact_only = false, stripe_price_id = null
where id = 'bigger';

update public.subscription_tiers set
  name = 'YGTeeV 6', range_label = '500+',     max_active = 500,   price_cents = 0,
  is_contact_only = true, stripe_price_id = null
where id = 'mega';

-- Verify
select id, display_order, name, range_label, max_active,
       (price_cents / 100.0) as price_usd, is_contact_only, stripe_price_id
from public.subscription_tiers
order by display_order;
