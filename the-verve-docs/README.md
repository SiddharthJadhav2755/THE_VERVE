# THE VERVE — Premium Fashion E-Commerce

**Define Your Presence.**

A complete, working e-commerce experience for THE VERVE, delivered as a **single self-contained HTML application** (`the-verve-store.html`) plus a production backend blueprint for the full Next.js + PostgreSQL stack.

---

## 1. What's in this package

| File | Purpose |
|---|---|
| `the-verve-store.html` | The entire storefront + admin platform in one file. Open it in any modern browser — no server, no build step, no dependencies. |
| `the-verve-docs/README.md` | This file. |
| `the-verve-docs/database-schema.sql` | Production PostgreSQL schema: 20+ tables, foreign keys, indexes, constraints, Row Level Security policies. |
| `the-verve-docs/backend-blueprint.md` | Production architecture: Next.js routes, Razorpay server-side verification & webhooks, Supabase Auth/Storage, Shiprocket, Resend, env vars, deployment, security checklist, SEO, test plan. |
| `the-verve-docs/adding-your-images.md` | How to add your own photography — product photos and the landing-page hero — by uploading from your computer, or baked into the source. |
| `the-verve-docs/deploying-your-store.md` | Put the store online free in ~5 minutes: Netlify Drop / Cloudflare Pages / Vercel / GitHub Pages, custom domain, update workflow, honest limits of the demo online. |
| `deploy/index.html` + `the-verve-deploy.zip` | The deploy-ready package — drag the zip onto app.netlify.com/drop and the store is live. |
| `the-verve-source-parts/` | The app's source split into 9 maintainable modules (CSS, data, core, storefront, product, commerce, accounts, admin, events) + `build.sh` that reassembles the HTML. |

## 2. Quick start

1. Double-click `the-verve-store.html` (or serve it: `npx serve .`).
2. Shop, add to bag, apply coupons, check out, place orders — everything works.
3. All data persists in your browser's `localStorage` (cart, account, orders, wishlist).

### Demo credentials

| Role | Where | Email | Password |
|---|---|---|---|
| Customer | `#/account` | `demo@theverve.in` | `Verve@Demo1` |
| Administrator | `#/admin` (or footer → Admin Console) | `admin@theverve.in` | `Verve@Admin2026` |

Passwords are hashed with SHA-256 before storage. **This is a demo build** — production auth must run server-side (Supabase Auth), never in the browser.

There is exactly **one admin login**. A versioned migration (`meta.authVer`) replaces any older admin account and clears stale sessions on first load of a new build, so you always land on the login page — never inside an old session. The documented admin credentials are a **self-healing login**: if the stored hash ever diverges (password changed via Profile, hash seeded in a non-secure context, stale local copy) or the account record is missing, entering `admin@theverve.in` / `Verve@Admin2026` repairs the account and signs you in — it also bypasses the 8-attempts/15-min rate limiter, which wrong passwords still trigger. **Reset Demo Data now clears the rate-limit counters too.** The admin is not a customer: demo orders belong to the demo customer (`meta.dataVer` migration moves any admin-owned orders), the header person-icon reads **ADMIN** and opens `#/admin` when the admin is signed in, and opening `#/account` as admin shows a notice pointing to the Admin Console. If an older copy of `the-verve-store.html` behaves oddly, replace it with the latest build — migrations only run in the current file.

## 3. What works in the demo build

**Storefront**
- Rotating announcement bar (editable in Admin → Marketing)
- Full-screen editorial hero, marquee, featured collection, category tiles, best-sellers rail, brand philosophy, campaign mosaic, Instagram grid, newsletter
- Shop with live filters (category, size, colour swatches, fit, price) + 5 sort orders
- Collections: New Arrivals, Oversized, Premium, Streetwear, Essentials, Limited Edition, Best Sellers
- Product pages: multi-image gallery, hover/tap zoom, colour & size selection with per-variant stock, size guide, PIN-code delivery checker, quantity, add-to-bag / buy-now, accordions (description / fabric & care / delivery), related products, recently viewed, sticky mobile buy bar
- 13 clearly-marked demo products with independent inventory per colour × size (including sold-out and low-stock states)

**Commerce**
- Cart drawer + cart page, quantity clamped to live stock, persistence across sessions
- Coupons: `VERVE10` (10%), `FIRST200` (₹200 off ≥₹999), `FREESHIP` — with min-order and usage rules
- Indian GST computed per slab (5% ≤₹1,000 / 12% >₹1,000, shown as "inclusive")
- Shipping rules: free ≥₹1,999, else ₹99; COD fee ₹49 (all editable in Admin → Settings)
- Checkout with full validation, guest checkout, address saving
- Payment: simulated Razorpay modal (UPI / Card / Net Banking / Wallet) + Cash on Delivery, with a "simulate payment failure" test path — orders are only created after the simulated server-side verification
- Order confirmation, printable tax invoice, transactional emails (simulated Resend outbox), order tracking with status timeline, cancellation & return requests

**Accounts**
- Register (with email verification code flow), login, logout, forgot-password (simulated email), rate limiting
- Dashboard, order history, wishlist, saved addresses (CRUD), profile, password change

**Admin console (`#/admin`)**
- Dashboard: revenue, orders, AOV, customers, 6-month sales chart (SVG), best sellers, low stock, recent orders
- Products: search, create/edit (**image manager — drag-drop / file-picker uploads, cover selection**, colours, sizes, tags, per-variant inventory grid), publish/unpublish, delete. See `adding-your-images.md`.
- Orders: search & filter, status workflow (10 states) that appends to the customer timeline and triggers emails, AWB/tracking entry, cancellation/return approvals, refunds
- Customers: list, lifetime value, purchase history
- Marketing: coupons CRUD, announcements, newsletter list + CSV export, abandoned carts, email log, review moderation
- Content: hero editor (headline/CTAs, **campaign image uploaded from your computer** — no URL fields), social links, policy & story page editors
- Settings: shipping fees, analytics keys, reset-demo-data

**Quality**
- Automated test suite (Admin → Diagnostics): 19 tests covering money maths, GST slabs, cart rules, oversell protection, coupon rules, order creation, inventory decrement, emails, auth guards — **19/19 passing**
- SEO: per-route titles/descriptions, Product JSON-LD structured data, Open Graph tags
- GA4 + Meta Pixel loaders wired (activate by setting IDs in `VERVE_CONFIG`)
- Responsive mobile-first layouts, keyboard-accessible controls, reduced-motion support

## 4. Honest limitations of this build

This environment delivers static, single-file web apps — it cannot host a Node/Next.js server, PostgreSQL database, or real payment credentials. Therefore:

1. **Payments are simulated.** The checkout shows exactly how the Razorpay flow will feel; no real money moves. The production integration (server-side order creation, signature verification, webhooks) is specified in `backend-blueprint.md`.
2. **Data lives in `localStorage`.** Real users on real devices need the PostgreSQL schema + Supabase backend (provided).
3. **Order/status emails are simulated** (viewable in Admin → Marketing → Email log). What IS functional now: the contact form and every **EMAIL CUSTOMER** button in the admin open the visitor's/mail-app with a prefilled message addressed to the company inbox `jadhavsiddharth576@gmail.com` — press send there and it really arrives. Newsletter signups are stored in the admin (exportable as CSV). Fully automated store-to-customer email needs Resend + the production backend.
4. **Demo data is clearly marked** — products carry a "Demo product" notice and the admin shows a "DEMO DATA" badge. No fake customer reviews are seeded; the review flow is real and moderated by you. This build carries `meta.seedVer: 3` — on first load, any older copy's data (orders, carts, uploads) is wiped and reseeded fresh, so every browser starts clean.
5. **Policies (privacy/terms/shipping/returns) are drafted templates** — have legal counsel review before launch. The live contact email is `jadhavsiddharth576@gmail.com` (set in `02-data.part`, `DEFAULT_SETTINGS` → `contact`); the phone number is still a placeholder.
6. **Imagery is web-sourced** for the demo catalogue. Replace it with your brand photography via Admin → Products → **upload from your computer** (see `adding-your-images.md`); for images that survive "Reset Demo Data", bake them into the seed data and rebuild. Instagram handle `@theverve.in` and social links are placeholders.
7. **Brand assets are integrated** — the supplied TV monogram wordmark is processed into transparent PNGs and used in the header (dark + ivory variants for the transparent-over-hero state), footer, admin sidebar and favicon. The landing-page hero is the supplied floating-tee campaign image, embedded in the file. Both live in `02-data.part` (the `LOGO` constant and `IMG.hero`) — swap them there and run `build.sh` to change them. A `meta.heroVer` migration re-points existing browsers to the current baked-in hero on first load; bump it when you change `IMG.hero`.
