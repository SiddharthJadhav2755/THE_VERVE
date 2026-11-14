-- ============================================================================
-- THE VERVE — Production Database Schema (PostgreSQL 15+ / Supabase)
-- Defines: enums, 21 relational tables, foreign keys, indexes, constraints,
--          and Row Level Security policies.
-- Usage (Supabase SQL editor or psql):  psql "$DATABASE_URL" -f database-schema.sql
-- ============================================================================

create extension if not exists "uuid-ossp";

-- ---------------------------------------------------------------- enums ----
create type user_role        as enum ('customer','admin');
create type order_status     as enum ('order_placed','payment_confirmed','processing','packed','shipped','out_for_delivery','delivered','cancelled','returned','refunded');
create type payment_method   as enum ('razorpay','cod');
create type payment_status   as enum ('created','paid','cod_pending','failed','refunded');
create type coupon_type      as enum ('percent','flat','freeship');
create type review_status    as enum ('pending','approved','rejected');
create type request_type     as enum ('cancel','return');
create type request_status   as enum ('requested','approved','declined');

-- ---------------------------------------------------------------- users ----
create table users (
  id            uuid primary key default uuid_generate_v4(),
  email         citext unique not null,
  phone         text check (phone ~ '^[6-9][0-9]{9}$'),
  full_name     text not null check (length(btrim(full_name)) between 2 and 80),
  role          user_role not null default 'customer',
  email_verified_at timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
-- NOTE: passwords/auth are owned by Supabase auth.users (never store hashes here).

create table addresses (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references users(id) on delete cascade,
  label       text not null default 'Home',
  line1       text not null,
  area        text not null,
  city        text not null,
  state       text not null,
  pin_code    text not null check (pin_code ~ '^[1-9][0-9]{5}$'),
  country     text not null default 'India',
  is_default  boolean not null default false,
  created_at  timestamptz not null default now()
);
create index idx_addresses_user on addresses(user_id);

-- ----------------------------------------------------------- catalogue -----
create table categories (
  id          uuid primary key default uuid_generate_v4(),
  slug        text unique not null check (slug ~ '^[a-z0-9-]+$'),
  name        text not null,
  tagline     text,
  image_url   text,
  position    int not null default 0
);

create table products (
  id            uuid primary key default uuid_generate_v4(),
  sku           text unique not null,
  slug          text unique not null check (slug ~ '^[a-z0-9-]+$'),
  name          text not null check (length(btrim(name)) between 2 and 120),
  description   text not null default '',
  category_id   uuid not null references categories(id),
  fit           text not null default 'Regular' check (fit in ('Oversized','Regular','Relaxed','Boxy')),
  gsm           int check (gsm between 100 and 600),
  material      text,
  care          jsonb not null default '[]'::jsonb,     -- ["Machine wash cold", ...]
  price_paise   int not null check (price_paise > 0),   -- store money in paise
  mrp_paise     int not null check (mrp_paise >= price_paise),
  is_new        boolean not null default false,
  is_featured   boolean not null default false,
  is_bestseller boolean not null default false,
  is_limited    boolean not null default false,
  published     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index idx_products_category on products(category_id);
create index idx_products_published on products(published) where published;
create index idx_products_price on products(price_paise);

create table product_images (
  id          uuid primary key default uuid_generate_v4(),
  product_id  uuid not null references products(id) on delete cascade,
  url         text not null,
  alt_text    text,
  position    int not null default 0
);
create index idx_images_product on product_images(product_id, position);

create table product_colors (
  id          uuid primary key default uuid_generate_v4(),
  product_id  uuid not null references products(id) on delete cascade,
  name        text not null,
  hex         text not null check (hex ~ '^#[0-9a-fA-F]{6}$'),
  image_index int not null default 0,
  unique (product_id, name)
);

create table variants (                    -- product × color × size
  id          uuid primary key default uuid_generate_v4(),
  product_id  uuid not null references products(id) on delete cascade,
  color_id    uuid not null references product_colors(id) on delete cascade,
  size        text not null,
  unique (product_id, color_id, size)
);
create index idx_variants_product on variants(product_id);

create table inventory (                   -- independent stock per variant
  variant_id  uuid primary key references variants(id) on delete cascade,
  quantity    int not null default 0 check (quantity >= 0),
  low_stock_threshold int not null default 3,
  updated_at  timestamptz not null default now()
);
-- oversell-safe decrement used by the checkout RPC:
create or replace function decrement_inventory(p_variant uuid, p_qty int)
returns boolean language plpgsql as $$
declare new_q int;
begin
  update inventory set quantity = quantity - p_qty, updated_at = now()
   where variant_id = p_variant and quantity >= p_qty
   returning quantity into new_q;
  return new_q is not null;
end $$;

-- ------------------------------------------------------------- coupons -----
create table coupons (
  id          uuid primary key default uuid_generate_v4(),
  code        text unique not null check (code ~ '^[A-Z0-9]{3,20}$'),
  type        coupon_type not null,
  value       int not null default 0,          -- percent points or paise
  min_subtotal_paise int not null default 0,
  usage_limit int,                             -- null = unlimited
  used_count  int not null default 0,
  active      boolean not null default true,
  starts_at   timestamptz, expires_at timestamptz,
  check (type <> 'percent' or value between 1 and 90)
);

-- ---------------------------------------------------------------- carts ----
create table carts (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references users(id) on delete cascade,   -- null = guest cart
  session_token text unique,                                 -- guest identity cookie
  coupon_code text references coupons(code),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index idx_carts_user on carts(user_id);

create table cart_items (
  id          uuid primary key default uuid_generate_v4(),
  cart_id     uuid not null references carts(id) on delete cascade,
  variant_id  uuid not null references variants(id),
  qty         int not null check (qty between 1 and 10),
  unique (cart_id, variant_id)
);

-- --------------------------------------------------------------- orders ----
create table orders (
  id            uuid primary key default uuid_generate_v4(),
  order_no      text unique not null,               -- TV-YYMMDD-XXXX
  invoice_no    text unique not null,               -- INV-...
  user_id       uuid references users(id),          -- null = guest order
  email         citext not null,
  phone         text not null,
  ship_name     text not null,
  ship_line1    text not null, ship_area text not null,
  ship_city     text not null, ship_state text not null,
  ship_pin      text not null, ship_country text not null default 'India',
  subtotal_paise int not null check (subtotal_paise > 0),
  discount_paise int not null default 0,
  coupon_code   text references coupons(code),
  shipping_paise int not null default 0,
  cod_fee_paise  int not null default 0,
  total_paise    int not null,
  status        order_status not null default 'order_placed',
  placed_at     timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index idx_orders_user on orders(user_id);
create index idx_orders_status on orders(status);
create index idx_orders_placed on orders(placed_at desc);

create table order_items (
  id          uuid primary key default uuid_generate_v4(),
  order_id    uuid not null references orders(id) on delete cascade,
  variant_id  uuid references variants(id),         -- keep nullable: history survives catalogue edits
  product_sku text not null,
  name        text not null,
  color_name  text not null,
  size        text not null,
  qty         int not null check (qty > 0),
  unit_price_paise int not null
);
create index idx_order_items_order on order_items(order_id);

create table order_timeline (
  id          uuid primary key default uuid_generate_v4(),
  order_id    uuid not null references orders(id) on delete cascade,
  status      order_status not null,
  note        text,
  created_at  timestamptz not null default now()
);
create index idx_timeline_order on order_timeline(order_id, created_at);

create table payments (
  id            uuid primary key default uuid_generate_v4(),
  order_id      uuid not null unique references orders(id) on delete cascade,
  method        payment_method not null,
  sub_method    text,                              -- upi | card | netbanking | wallet
  status        payment_status not null default 'created',
  gateway_order_id text,                           -- Razorpay order_xxx
  gateway_payment_id text,                         -- Razorpay pay_xxx
  signature_verified boolean not null default false,  -- set ONLY by server webhook
  amount_paise  int not null,
  paid_at       timestamptz,
  refunded_at   timestamptz
);

create table shipments (
  id          uuid primary key default uuid_generate_v4(),
  order_id    uuid not null references orders(id) on delete cascade,
  courier     text default 'Shiprocket',
  awb         text unique,
  label_url   text,
  tracking_url text,
  status      text,
  created_at  timestamptz not null default now()
);

create table return_requests (
  id          uuid primary key default uuid_generate_v4(),
  order_id    uuid not null references orders(id) on delete cascade,
  user_id     uuid references users(id),
  type        request_type not null,
  reason      text,
  status      request_status not null default 'requested',
  created_at  timestamptz not null default now(),
  decided_at  timestamptz
);
create index idx_returns_order on return_requests(order_id);

-- ------------------------------------------------------ social / content ---
create table wishlists (
  user_id     uuid not null references users(id) on delete cascade,
  product_id  uuid not null references products(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table reviews (
  id          uuid primary key default uuid_generate_v4(),
  product_id  uuid not null references products(id) on delete cascade,
  user_id     uuid not null references users(id) on delete cascade,
  rating      int not null check (rating between 1 and 5),
  title       text not null check (length(title) <= 80),
  body        text not null check (length(body) between 4 and 800),
  status      review_status not null default 'pending',
  created_at  timestamptz not null default now(),
  unique (product_id, user_id)
);
create index idx_reviews_product on reviews(product_id) where status = 'approved';

create table newsletter_subscribers (
  email       citext primary key,
  source      text default 'footer',
  created_at  timestamptz not null default now()
);

create table contact_messages (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null, email citext not null,
  subject     text, message text not null,
  handled     boolean not null default false,
  created_at  timestamptz not null default now()
);

create table site_settings (
  key         text primary key,        -- 'hero', 'announcements', 'shipping', 'social', 'page:privacy'
  value       jsonb not null,
  updated_at  timestamptz not null default now()
);

create table email_log (                 -- Resend outbox audit
  id          uuid primary key default uuid_generate_v4(),
  to_email    citext not null,
  kind        text not null,             -- order_confirmation | status_update | ...
  subject     text not null,
  resend_id   text,
  created_at  timestamptz not null default now()
);

-- updated_at trigger
create or replace function touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger trg_users_touch before update on users for each row execute function touch_updated_at();
create trigger trg_products_touch before update on products for each row execute function touch_updated_at();
create trigger trg_orders_touch before update on orders for each row execute function touch_updated_at();

-- ======================================================= Row Level Security
alter table users enable row level security;
alter table addresses enable row level security;
alter table products enable row level security;
alter table product_images enable row level security;
alter table product_colors enable row level security;
alter table variants enable row level security;
alter table inventory enable row level security;
alter table categories enable row level security;
alter table coupons enable row level security;
alter table carts enable row level security;
alter table cart_items enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table order_timeline enable row level security;
alter table payments enable row level security;
alter table shipments enable row level security;
alter table return_requests enable row level security;
alter table wishlists enable row level security;
alter table reviews enable row level security;
alter table newsletter_subscribers enable row level security;
alter table site_settings enable row level security;

-- helper: current user's role from public.users (mirrors auth.uid())
create or replace function is_admin() returns boolean language sql stable as $$
  select exists (select 1 from users u where u.id = auth.uid() and u.role = 'admin');
$$;

-- public catalogue: readable when published; writable only by admins
create policy "public read products" on products for select using (published or is_admin());
create policy "admin write products" on products for all using (is_admin()) with check (is_admin());
create policy "public read images"   on product_images for select using (true);
create policy "admin write images"   on product_images for all using (is_admin()) with check (is_admin());
create policy "public read colors"   on product_colors for select using (true);
create policy "admin write colors"   on product_colors for all using (is_admin()) with check (is_admin());
create policy "public read variants" on variants for select using (true);
create policy "admin write variants" on variants for all using (is_admin()) with check (is_admin());
create policy "public read inventory" on inventory for select using (true);
create policy "admin write inventory" on inventory for all using (is_admin()) with check (is_admin());
create policy "public read categories" on categories for select using (true);
create policy "admin write categories" on categories for all using (is_admin()) with check (is_admin());

-- users see only their own rows
create policy "own profile"    on users for select using (id = auth.uid() or is_admin());
create policy "own addresses"  on addresses for all using (user_id = auth.uid() or is_admin()) with check (user_id = auth.uid());
create policy "own wishlist"   on wishlists for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- orders: customer reads own; writes happen via service_role (checkout RPC) only
create policy "own orders"      on orders for select using (user_id = auth.uid() or is_admin() or user_id is null and false);
create policy "own order items" on order_items for select using (exists (select 1 from orders o where o.id = order_id and (o.user_id = auth.uid() or is_admin())));
create policy "own timeline"    on order_timeline for select using (exists (select 1 from orders o where o.id = order_id and (o.user_id = auth.uid() or is_admin())));
create policy "own payments"    on payments for select using (exists (select 1 from orders o where o.id = order_id and (o.user_id = auth.uid() or is_admin())));
create policy "own shipments"   on shipments for select using (exists (select 1 from orders o where o.id = order_id and (o.user_id = auth.uid() or is_admin())));
create policy "own requests"    on return_requests for select using (user_id = auth.uid() or is_admin());
create policy "create request"  on return_requests for insert with check (user_id = auth.uid());

-- coupons: public read of active codes only (validation itself is server-side)
create policy "read active coupons" on coupons for select using (active and is_admin() or is_admin());

-- reviews: anyone reads approved; authors create own pending; admins moderate
create policy "read approved reviews" on reviews for select using (status = 'approved' or user_id = auth.uid() or is_admin());
create policy "create own review"     on reviews for insert with check (user_id = auth.uid());
create policy "admin moderates"       on reviews for update using (is_admin());

-- newsletter + settings
create policy "anyone subscribes" on newsletter_subscribers for insert with check (true);
create policy "admin reads subs"  on newsletter_subscribers for select using (is_admin());
create policy "public read settings" on site_settings for select using (true);
create policy "admin write settings" on site_settings for all using (is_admin()) with check (is_admin());

-- carts: owner (by user) or guest (by session token match handled server-side)
create policy "own cart"      on carts for select using (user_id = auth.uid() or is_admin());
create policy "own cart items" on cart_items for all using (exists (select 1 from carts c where c.id = cart_id and (c.user_id = auth.uid() or is_admin()))) with check (exists (select 1 from carts c where c.id = cart_id and (c.user_id = auth.uid() or is_admin())));

-- ============================================================================
-- SEED: categories
-- ============================================================================
insert into categories (slug, name, tagline, position) values
  ('oversized-t-shirts','Oversized T-Shirts','Drape. Volume. Presence.',1),
  ('premium-t-shirts','Premium T-Shirts','Heavyweight staples, refined.',2),
  ('streetwear','Streetwear','The uniform of the bold.',3),
  ('new-arrivals','New Arrivals','Fresh off the atelier.',4),
  ('essentials','Essentials','Foundations of the everyday.',5),
  ('limited-edition','Limited Edition','Few made. None repeated.',6);
