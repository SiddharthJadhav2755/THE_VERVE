# Adding your own images — THE VERVE

Two ways to put your real photography into the store, from "no code at all"
to "baked into the source". Method 1 is the one built for you — there are no
image-URL fields anywhere in the admin; you work only with files from your
computer.

---

## Method 1 — Upload from your computer (recommended, no code)

### Product photos

1. Open `the-verve-store.html` → footer **Admin Console** (or `#/admin`), sign in as `admin@theverve.in` / `Verve@Admin2026`.
2. **Products** → **EDIT** on any product (or **+ ADD PRODUCT** for a new one).
3. In the **PRODUCT IMAGES** section either **drag photos onto the dashed drop zone** or press **CHOOSE FILES** and pick one or more images (JPG · PNG · WebP).
4. Manage the thumbnails:
   - The first image is the **COVER** (burgundy badge) — it shows on shop cards and the hero of the product page. Hover any other thumb and press **★** to make it the cover.
   - Hover and press **✕** to remove an image.
5. Press **SAVE PRODUCT**. The storefront updates instantly — shop card, product-page gallery, cart thumbnails, admin list.

### The landing-page (hero) image

1. **Admin → Content** → the **Hero section** card.
2. **Drag your campaign image onto the drop zone** or press **CHOOSE IMAGE** (one image, JPG · PNG · WebP — auto-compressed to a 1600 px longest edge).
3. The small preview next to the drop zone shows what will go live. **RESET TO DEFAULT** puts the baked-in campaign image back.
4. Press **SAVE HERO**, then open the storefront — the landing page background is your image. Wide landscape shots (16:9 or wider, subject on the right) work best: the headline sits on the left.

**What happens to your files:** every photo is auto-resized (1100 px for products, 1600 px for the hero) and re-compressed to JPEG before storage, so a typical photo of 2–5 MB shrinks about 30×. Nothing is uploaded anywhere — files never leave your computer; the compressed copy is kept inside your browser.

## Method 2 — Baked into the source (permanent, survives "Reset Demo Data")

Method 1 lives in your browser's storage, so **Admin → Settings → Reset Demo
Data wipes it**. To make images permanent, put them in the seed data:

1. Put your files in a folder next to the HTML, e.g. `images/my-tee-front.jpg`.
2. Edit `the-verve-source-parts/02-data.part` — find the product (ids `p01`…`p13`) and replace its `images:[CDN+'…', …]` with your paths:
   ```js
   images:['images/my-tee-front.jpg','images/my-tee-back.jpg'],
   ```
   For the hero, replace the `IMG.hero` data-URL (or run `scripts/swap_hero.py` with your file) and bump `meta.heroVer` so existing browsers pick it up.
3. Rebuild: `bash the-verve-source-parts/build.sh` — this regenerates `the-verve-store.html`.
   (Relative paths like `images/…` load when the file is opened directly or served with `python3 -m http.server`; they also work from a host like Vercel/Netlify.)

## Limits & tips, honestly stated

- **Storage budget:** the demo keeps everything in `localStorage` (~5 MB). After compression that's roughly **30–40 product photos**. You'll get a warning toast when approaching the limit, and a clear error if a save fails.
- **Per-browser, not per-server:** uploaded images exist only in the browser you used — this is a local demo, other devices or visitors won't see them. For a real multi-device catalogue use Method 2 now, and the PostgreSQL + Supabase Storage stack in `backend-blueprint.md` for production.
- **Photo tips:** 3:4 portrait crops look best in the cards; shoot front / alternate / back; keep the product centred — the gallery does a hover zoom, so 1100 px on the long edge is plenty sharp. For the hero, keep text-free space on the left for the headline.
- **Verified end-to-end:** file-picker upload, drag-and-drop, make-cover, remove, save → reload → storefront (products), hero upload → save → live landing page, and the full diagnostics suite (19/19) were all tested in a real headless Chrome session; a 1600 px test photo compressed to ~22 KB, a 1600×900 hero to ~21 KB.

*(Feature added 2026-11-13; hero upload + URL fields removed and single-admin login enforced 2026-11-14. Source changes: image manager and hero widget in `08-admin.part`, event wiring in `09-events-boot.part`, compression + grid styles in `01-head.part`, migrations in `02-data.part`.)*
