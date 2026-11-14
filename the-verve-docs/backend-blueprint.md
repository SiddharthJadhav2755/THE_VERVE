# THE VERVE — Production Backend Blueprint

This document specifies exactly how to take the working demo (`the-verve-store.html`) to a production platform on the stack chosen for the brand: **Next.js 16 + TypeScript + Tailwind + shadcn/ui · Supabase (PostgreSQL, Auth, Storage) · Razorpay · Shiprocket · Resend · Vercel**.

The demo already implements every screen, rule and flow (cart maths, GST slabs, coupon rules, inventory safety, order lifecycle, admin workflows); the blueprint maps each of them to server-side code.

---

## 1. Project structure

```
the-verve/
├─ app/
│  ├─ (storefront)/
│  │  ├─ page.tsx                        # /            homepage
│  │  ├─ shop/page.tsx                   # /shop        + searchParams filters
│  │  ├─ collections/page.tsx
│  │  ├─ collections/[slug]/page.tsx
│  │  ├─ product/[slug]/page.tsx         # generateMetadata + JSON-LD
│  │  ├─ cart/page.tsx
│  │  ├─ checkout/page.tsx
│  │  ├─ order-confirmation/[orderNo]/page.tsx
│  │  ├─ account/{page,orders,wishlist,addresses,profile}/…
│  │  ├─ track-order/page.tsx
│  │  ├─ about | contact | faq | shipping-policy | returns | privacy | terms
│  ├─ admin/
│  │  ├─ layout.tsx                      # server-side admin guard (middleware + role check)
│  │  ├─ page.tsx  products/  orders/  customers/  analytics/  coupons/  marketing/  content/  settings/
│  ├─ api/
│  │  ├─ payments/create-order/route.ts      # Razorpay order creation (server)
│  │  ├─ payments/verify/route.ts            # signature verification → order creation
│  │  ├─ webhooks/razorpay/route.ts          # payment.captured / refund.processed
│  │  ├─ webhooks/shiprocket/route.ts        # status pushes → order_timeline
│  ├─ sitemap.ts  robots.ts  opengraph-image.tsx
├─ components/ (ui/ from shadcn, store/, admin/)
├─ lib/
│  ├─ supabase/{client,server,admin}.ts  # anon client, RLS client, service-role client
│  ├─ razorpay.ts  shiprocket.ts  resend.ts
│  ├─ money.ts        # paise maths + GST slabs (port of demo cartCalc)
│  ├─ ratelimit.ts    # @upstash/ratelimit (Redis)
│  └─ validation.ts   # zod schemas for every form/API input
├─ supabase/migrations/…                  # database-schema.sql split into ordered migrations
├─ tests/ (vitest unit + playwright e2e)
└─ .env.example
```

## 2. Checkout & payments — the only safe Razorpay flow

Never trust the frontend. The demo's `payNowSucceeded()` becomes:

**Step 1 — create gateway order (server):**
```ts
// app/api/payments/create-order/route.ts
const { amountPaise, receipt } = await z.object({ amountPaise: z.number().int().positive() })
  .parse(await req.json());
// recompute amount server-side from the user's cart — never accept client totals
const rp = new Razorpay({ key_id: process.env.RAZORPAY_KEY_ID!, key_secret: process.env.RAZORPAY_KEY_SECRET! });
const order = await rp.orders.create({ amount: amountPaise, currency: 'INR', receipt });
```

**Step 2 — open Razorpay Checkout** (`window.Razorpay` with `key_id` only — the secret never reaches the browser).

**Step 3 — verify signature server-side, then create the DB order in one transaction:**
```ts
const expected = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET!)
  .update(`${rpOrderId}|${rpPaymentId}`).digest('hex');
if (expected !== signature) return new Response('invalid signature', { status: 400 });
// inside a supabase transaction:
//   verify each cart line: decrement_inventory(variant, qty)  -- oversell-safe RPC
//   insert orders, order_items, order_timeline, payments(signature_verified=true)
//   increment coupon.used_count
//   queue confirmation email
```

**Step 4 — webhooks as source of truth.** `POST /api/webhooks/razorpay` verifies `x-razorpay-signature` (webhook secret), handles `payment.captured`, `payment.failed`, `refund.processed`, and is idempotent (`gateway_payment_id` unique). COD orders skip the gateway but still run the same transaction with `payment_status='cod_pending'`.

**Refunds:** admin action → `rp.payments.refund(payment_id, amount)` → webhook confirms → order status `refunded`, refund email via Resend.

## 3. Auth & security checklist

- Supabase Auth (email+password, magic link for verification, signed reset tokens) — `users.id` mirrors `auth.uid()`.
- Admin = `users.role='admin'`, enforced by RLS (`is_admin()`) **and** middleware on `/admin/*`; service-role key used only in server routes.
- Every API input validated with zod; every price recomputed server-side from DB rows.
- Rate limits (Upstash Redis): login 8/15min/IP, register 5/h, checkout 10/h, newsletter 5/h.
- Sessions: httpOnly, Secure, SameSite=Lax cookies (Supabase SSR helper) — CSRF-safe for the cookie-based mutations; Razorpay webhook verified by HMAC.
- XSS: React escaping + no `dangerouslySetInnerHTML` except the admin policy editor, sanitised server-side with `sanitize-html`.
- Headers on Vercel: strict CSP, HSTS, X-Frame-Options DENY, Referrer-Policy strict-origin-when-cross-origin.
- Secrets only in environment variables — never in client bundles (`NEXT_PUBLIC_` prefix reserved for `RAZORPAY_KEY_ID`, GA/Pixel IDs).

## 4. Integrations

| Service | Use | Notes |
|---|---|---|
| **Supabase Storage** | Product imagery (`products/{sku}/…`), campaign art | Public read bucket; admin-only write; Next/Image with remotePatterns. Cloudinary works too (`f_auto,q_auto` transforms). |
| **Shiprocket** | Label + AWB creation on `Packed`; tracking webhook updates `order_timeline` + status email; serviceability/PIN check API powers the product-page checker. |
| **Resend** | `order_confirmation`, `status_update`, `refund`, `welcome`, `verify`, abandoned-cart sequence (1h/24h cron via Vercel Cron scanning `carts.updated_at`). Branded HTML templates matching the demo outbox. |
| **GA4 / Meta Pixel** | Loaded from `NEXT_PUBLIC_GA_ID` / `NEXT_PUBLIC_PIXEL_ID`; events: view_item, add_to_cart, begin_checkout, purchase. |
| **Vercel Cron** | Abandoned-cart recovery, nightly low-stock digest to admin. |

## 5. Environment variables

```bash
NEXT_PUBLIC_SITE_URL=https://theverve.in
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_ROLE_KEY=...            # server only
RAZORPAY_KEY_ID=rzp_live_xxx             # public by design
RAZORPAY_KEY_SECRET=...                  # server only
RAZORPAY_WEBHOOK_SECRET=...
SHIPROCKET_EMAIL=... SHIPROCKET_PASSWORD=... SHIPROCKET_WEBHOOK_TOKEN=...
RESEND_API_KEY=... RESEND_FROM="THE VERVE <care@theverve.in>"
NEXT_PUBLIC_GA_ID=G-... NEXT_PUBLIC_PIXEL_ID=...
UPSTASH_REDIS_REST_URL=... UPSTASH_REDIS_REST_TOKEN=...
```

## 6. SEO & performance

- `app/sitemap.ts` renders products/collections from DB; `robots.ts` disallows `/admin`, `/account`, `/checkout`, `/api`.
- Product pages: `generateMetadata` (title, description, canonical, OG image from first product shot) + `Product` JSON-LD (price, availability from inventory) + `BreadcrumbList`.
- URLs identical to the demo routes (`/product/[slug]`, `/collections/[slug]`) so the demo's IA carries over.
- Performance: ISR (`revalidate: 300`) for catalogue pages, `next/image` AVIF/WebP, fonts self-hosted subset, target LCP < 2.5s / CLS < 0.1.

## 7. Migrating the demo's logic 1:1

| Demo (`the-verve-store.html`) | Production |
|---|---|
| `cartCalc()` totals, GST slabs (5%/12% inclusive) | `lib/money.ts` — same formulas, unit-tested |
| `addToCart` stock guard | `decrement_inventory` RPC + RLS-scoped cart writes |
| `createOrder()` | `verify` route transaction (§2 step 3) |
| Coupons & min-order rules | `coupons` table + server-side `validateCoupon()` |
| Order status timeline + emails | `order_timeline` inserts + Resend templates |
| Admin console screens | `/admin/*` React screens on the same RLS-guarded queries |
| In-app 19-test suite | Vitest (unit: money/coupons/GST) + Playwright (e2e: browse→pay→admin ship→refund) run in CI |

## 8. Launch checklist

1. `supabase db push` migrations; seed categories; create admin user; disable demo signups.
2. Replace demo catalogue: upload real products + photography via `/admin/products`.
3. Legal review of policy pages (they ship as drafts); confirm registered business details, GSTIN on invoices.
4. Razorpay: activate live keys, configure webhook URL + secret, test ₹1 live transaction end-to-end including refund.
5. Shiprocket: pickup location, courier priorities, label test.
6. Domain on Vercel, DNS, HSTS; GA4 + Search Console verification + sitemap submit; Meta Pixel + Conversions API.
7. Load the real wordmark asset; favicon + OG image.
8. Run the Playwright suite against staging; then go live.
