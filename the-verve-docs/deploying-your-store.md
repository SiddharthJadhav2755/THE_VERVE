# Deploying THE VERVE — from your computer to a live URL

The whole store is **one file** (`index.html`, ~390 KB) with no server, no
database and no build step. Any static host can serve it, and the built-in
migrations handle visitors whose browsers have older data. This guide takes
you from zero to a live URL in about five minutes, free.

**What's in `download/`:**

| File | What it is |
|---|---|
| `deploy/index.html` | The store, ready to upload (rename nothing) |
| `the-verve-deploy.zip` | The same file zipped — drag **this** onto a host |

---

## Option A — Netlify Drop (fastest, recommended)

Netlify is free for this kind of site, serves HTTPS automatically, and has
servers in India (Mumbai) so it loads fast for your customers.

1. Open **https://app.netlify.com/drop** in your browser and sign up / log in (free — Google login works).
2. **Drag `the-verve-deploy.zip`** from your Downloads onto the drop zone. Netlify uploads it and, in under a minute, gives you a live URL like `https://random-name-12345.netlify.app`.
3. Click it — your store is live. Share that link anywhere (Instagram bio, WhatsApp status, business cards).
4. **Give it a proper name:** Site configuration → *Change site name* → e.g. `theverve` → your URL becomes `https://theverve.netlify.app` (if taken, try `theverve-store`, `theverveofficial`, …).
5. **To update the store later:** change the source parts → `bash build.sh` → re-zip (or re-drag `deploy/index.html`) → Netlify replaces the old site. Visitors' browsers migrate their saved data automatically on the next load — you never have to ask them to clear anything.

> Netlify Drop needs an account to keep a site permanently. Without one the
> site expires after a day — so do the 1-minute signup.

## Option B — Cloudflare Pages (also excellent)

1. Log in at **https://dash.cloudflare.com** (free account) → **Workers & Pages** → **Create** → **Pages** → **Upload assets**.
2. Name the project `the-verve`, drag **`the-verve-deploy.zip`**, deploy. You get `https://the-verve.pages.dev`.
3. Updating: the same project page → *Create new deployment* → upload the new zip. Cloudflare keeps old versions so you can roll back.

## Option C — Vercel or GitHub Pages

- **Vercel:** `vercel login` → `vercel deploy --prod` inside a folder holding `index.html` (needs the CLI or GitHub). Free tier fine.
- **GitHub Pages:** create a repo → upload `index.html` → Settings → Pages → deploy from branch. URL: `https://<username>.github.io/<repo>`. Slower to set up; fine if you already use GitHub.

All of them serve the same file — pick whichever you find easiest to reach
later. Option A is the one with the least clicking.

## Custom domain (₹700–₹1,200/year)

Once the site is live you can put your own `.com`/`.in` on it:

1. Buy the domain at any registrar (GoDaddy, Namecheap, Hostinger, Cloudflare).
2. In Netlify: Site configuration → **Domains** → *Add a domain* → enter it → follow the DNS instructions (either point nameservers to Netlify or add an A/CNAME record at your registrar).
3. HTTPS is issued automatically within minutes. In Cloudflare Pages the flow is the same (*Custom domains* tab).

## What works on the live site — and what stays local

Works exactly as in the demo: landing page, shop, filters, product pages, wishlist, cart, coupon codes, checkout flow, order tracking, policy pages, admin console (login, product management with image uploads, hero upload, orders board, analytics).

Honest limits — the demo keeps its data **in each visitor's own browser**:

- **Orders placed on the live site** show up only in *that customer's* browser; you won't receive them anywhere. The admin Orders board only sees orders created in your own browser. Real order collection needs the production backend described in `backend-blueprint.md` (Supabase + Razorpay + Shiprocket + Resend).
- **Admin image uploads are per-browser:** photos you upload from your laptop appear in your browser only — other visitors see the baked-in seed images. To change what *everyone* sees, bake images into `02-data.part` (see `adding-your-images.md`, Method 2) and redeploy.
- **The demo credentials are public** in the login screen note — before showing the site to real users, it's wise to keep the admin URL to yourself (`…/​#/admin` is not linked prominently) and rotate the password in the source before deploying.

## Pre-flight checklist (30 seconds)

- [ ] You're uploading `deploy/index.html` / `the-verve-deploy.zip` from the **latest** build — check it's ~392 KB, not an older copy.
- [ ] After deploy, open the URL → hero shows the floating-tee campaign image → header monogram crisp.
- [ ] Footer → Admin Console → sign in → Diagnostics shows **19 / 19**.
- [ ] Bookmark your live URL and the Netlify/Cloudflare dashboard — that's where "Change site name" and "Add domain" live.

*(Guide added 2026-11-14. The deployed file is the same build verified locally: HTTP render check + fonts + admin login + 19/19 diagnostics.)*
