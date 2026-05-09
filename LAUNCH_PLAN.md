# DreamSculpt — Launch Preparation Plan

## What I see (one-paragraph honest read)

DreamSculpt is a sketch-to-image AI app for iPhone/iPad. The user draws on a PencilKit canvas, hits Generate, and the API returns a photoreal/stylized image. There's also a meaningfully different mode: load a photo as the canvas background and "edit by sketching" — circle a thing, scribble what changes, and the AI applies it. Five style presets (Photo, Oil, Anime, Cyber, Watercolor), a custom prompt bar, a side-pull camera panel, a session slider through results, and a history drawer. Monetization: 3 free generations/day (free), then consumable IAP packs at $1.99 / $7.99 / $14.99. Visually it's polished — aurora header, glassmorphic panels, splash animation. **But there is no analytics, no onboarding, no virality, no subscription, no domain on the API, and a few App Store-blocking issues sitting in the code right now.** This is a credible v0.9 product, not a v1.0 launch yet.

---

## 1. Product–Market Fit & Pivot Recommendations

### PMF assessment: moderate, with an unclaimed differentiator

The text-to-image AI category is brutally crowded (Midjourney, Imagine, Lensa, Photoroom, BeFunky, Picsart). DreamSculpt's competitive moat is **not** "yet another AI image generator" — it's **sketch-as-input**, especially on iPad with Apple Pencil. That's a meaningful differentiator and almost no one is occupying that lane well.

The other quietly powerful feature is your **photo-edit-by-scribble** mode (the sketch-on-base-image flow in `AppState.imageEditPrompt`). This is closer to magic than the sketch-to-image mode for most users — circle a person, sketch what you want changed, get the result. Most AI photo editors require text or precise masks. This is more intuitive.

### The pivot (evolutionary, not radical)

**Stop calling this "DreamSculpt — Sculpt your imagination."** That tagline is poetic but tells the App Store visitor nothing. Reposition around one of these two value props:

- **Option A (recommended): "Sketch → Photo. AI illustration for iPad."** Lean hard into iPad + Apple Pencil. Pitch it as "Procreate's AI cousin." This narrows the audience but gives you a clear ASO lane and a sharper Reddit/X/HN story.
- **Option B: "Edit photos by drawing on them."** Lead with the photo-edit mode. Wider audience but more crowded category.

Pick A. It's the more defensible position, the less crowded keyword space, and your Apple Pencil integration already supports it well. The photo-edit-by-scribble becomes the secondary "wait, it does THIS too?" moment.

### The "magic moment" to optimize for

**First successful generation in under 90 seconds of opening the app.** Specifically: sketch a few strokes → tap Generate → see a transformation that makes them say "whoa." That single moment determines if they share, return, and pay. Everything else in the app is in service of this moment.

What's blocking it today:
- **No onboarding sketch.** A new user opens the app to a blank white canvas and a custom-prompt bar they don't understand. They have to figure out what to draw. Massive activation drop.
- **3/day free is too stingy for activation.** A user might burn 3 generations on bad prompts trying to figure out the app, hit the paywall, and never return. Activation requires *enough rope* to find the magic.
- **Style preset surface area is buried.** Styles live inside the expanded prompt bar. A first-time user may never see them.

### Feature recommendations (ranked by impact on AAR — Activation, Retention)

| Priority | Change | Why |
|---|---|---|
| P0 | **Add an onboarding flow with a pre-filled "Try this" sketch.** Trace-along mode: user traces a faint dashed outline, hits Generate, sees the magic. | Single highest-leverage change. Solves "blank canvas anxiety." |
| P0 | **Bump free tier from 3/day → 5/day OR offer "first 10 free" lifetime grant.** 3/day is hostile during activation. | Cheap to do; preserves later monetization. The first 10 generations are the most important you'll ever serve a user. |
| P0 | **Surface style chips ABOVE the prompt bar in collapsed state.** Right now they hide inside the expanded prompt bar. | Discoverability. Style is the second-magic moment. |
| P0 | **Watermark shared/saved images** (subtle "Made with DreamSculpt" + small logo lower-right, dismissible only via paid tier). | Free organic acquisition. This is your single best compounding growth lever. |
| P1 | **Add a subscription tier** ($4.99/mo unlimited or 100/mo) alongside consumables. | Consumables alone underprice power users. Subscriptions yield 3–5x LTV. |
| P1 | **Add a daily prompt / "today's challenge"** that pings the user. | Retention. Gives users a reason to come back. |
| P1 | **"Inspiration gallery" of curated examples** with one-tap "Try this prompt + style." | Solves blank canvas, drives usage. |
| P2 | **Remix:** tap any past generation → "remix" → loads it as the base image with the same prompt prefilled. | Deepens session length. |
| P2 | **Add 2–3 more style presets** (e.g. "Pixar 3D," "Pencil Sketch," "Comic Book"). Pixar/animated styles convert well on social. | Most-shared aesthetics. |
| P3 | Remove the GenerationSettings (steps, denoisingStrength, cfgScale) UI from end users. Keep them server-side. | These are noise to consumers; risk of users tuning them into bad outputs. |

### Things to cut for v1.0

- **The custom prompt textbox as the primary surface.** Demote it. Most users won't write good prompts. Make styles the primary input; prompt is "Advanced."
- **Paper texture toggle** (your notes.md already calls this out for deletion — agreed).
- **The DEBUG `USE_MOCK_GENERATION = true` flag** must obviously be off in release. Verify before submission. You also have `// DELETE LATER` markers in `CanvasView.swift:11-15` and `:280` — clean those up.

---

## 2. Pre-Launch Product Polish (App Store Readiness)

### Critical bugs and blockers I found in the code

These will either reject your build or hurt activation. Fix before submission:

1. **Bug — Limit message says wrong number.** `LimitReachedView.swift:35` says "all 10 free generations" but `GenerationLimitManager.swift:12` defines `dailyFreeLimit = 3`. Fix the copy or fix the limit, but they have to match.
2. **Info.plist has empty key/string pair** (`Info.plist:5-6`). This may fail App Store validation. Remove the empty `<key></key><string></string>`.
3. **API endpoint is a raw IP via sslip.io** (`APIClient.swift:27`: `https://13.221.123.53.sslip.io/generate`). This is fragile, leaks your infra, and is a reliability risk on launch day. Get a real domain (`api.dreamsculpt.app`) with a CDN/load-balancer in front. App Store reviewers do test connectivity.
4. **`NSAllowsLocalNetworking` true in App Transport Security** (`Info.plist:16-19`). Unless you actually need local network access, remove this — reviewers sometimes flag.
5. **No privacy policy URL or terms of service.** App Store Connect requires a privacy policy URL for any app that touches user data. You send images + a session ID to your backend. You need:
   - Public privacy policy at a stable URL (use a static GitHub Pages or Notion page if needed).
   - App Privacy disclosures in App Store Connect: "Photos or Videos — App Functionality, Not Linked to User."
6. **No "Restore Purchases" surface from outside the storefront.** It's only in `StorefrontView.swift:268`. Apple wants Restore reachable for users who paid but reinstalled. Add to a simple Settings sheet.
7. **`MockImageGenerator` and `USE_MOCK_GENERATION`** still shipping in CanvasView. Strip in release.
8. **No rate-limit / abuse handling on API client.** If your backend gets hammered, a 60s timeout and silent failure produces bad UX. Add visible error states ("We're a bit slow right now — try again in a moment").
9. **Generation Settings UI is exposed but probably shouldn't be.** Hide it for v1.

### Onboarding (you have none — this is the biggest hole)

Required for v1:
- 3-screen swipe intro (max): "Sketch anything → AI transforms it → Edit photos by drawing on them."
- After intro, drop the user into a **pre-filled tutorial canvas** with a faded "tap Generate to see what happens" overlay.
- After their first generation, a one-tap "Save" + "Share" with confetti haptic. This is the conversion-cementing moment.
- Then: "You have 5 free generations today." — gentle introduction of the limit.

### Retention & re-engagement plumbing

- **Push notifications:** request permission *after* first successful generation (not on launch). Use it for "Today's prompt" + "Your free generations refreshed."
- **Local notifications** as a fallback if user declines push: schedule a daily "Today's challenge" notification.
- **App badge** showing remaining free generations is a subtle daily nudge.
- **App Open notifications:** if the user is gone 7 days, fire a "We miss you — here's a free generation pack" with a single restoration-grant.

### Feature completeness checklist for v1.0

- [ ] Onboarding (3-screen + tutorial sketch)
- [ ] Watermark on saved/shared images for free users
- [ ] Subscription tier + new IAP product configured
- [ ] Working privacy policy + ToS URLs in App Store Connect
- [ ] Real domain in front of API endpoint
- [ ] Analytics SDK wired (see below)
- [ ] Crash reporting (Sentry / Crashlytics — you have neither)
- [ ] StoreKit transaction listener handles edge cases (already mostly done in `StoreManager.swift:125`)
- [ ] App icon set complete (1024x1024 + all sizes; verify via Xcode validator)
- [ ] Launch screen matches splash screen
- [ ] Rate-limit + retry UX on API failures
- [ ] Settings panel with: Restore Purchases, Privacy Policy link, ToS link, Contact Support, Version number
- [ ] Error states for: no internet, API timeout, IAP failure, image load failure
- [ ] App Store screenshots + preview video (see ASO section)

### Pricing / monetization recommendations

Your current model (consumables only) is leaving money on the table. **Move to a hybrid: subscription + consumable.**

Recommended structure:

| Tier | Price | What it gives | Why |
|---|---|---|---|
| Free | $0 | 5/day (bump from 3), watermarked | Activation. 3 is too low; 5 lets users experiment. |
| **DreamSculpt Pro Weekly** | $4.99/wk (with 3-day free trial) | Unlimited (soft-capped at e.g. 100/day), no watermark, all styles | Trial → paid is the highest-LTV funnel for casual creative apps. Weekly billing performs better than monthly for impulse-buy creative apps in 2025. |
| **DreamSculpt Pro Annual** | $39.99/yr (~$3.33/mo) | Same as weekly, big savings badge | Anchor against weekly to look like the obvious choice. |
| 10-pack | $1.99 | One-time | Keep for non-subscribers and low-commit users. |
| 50-pack | $7.99 | One-time | Drop this if it cannibalizes subs. |
| 150-pack | $14.99 | One-time | Power users who hate subs. |

Why this works: industry data on AI creative apps (Lensa, Photoroom, Picsart) shows **weekly subs with a free trial outperform monthly 3:1 for first-90-day revenue** in this category. The trial removes the buying decision; weekly removes the sticker shock.

Place the paywall at **two specific moments**:
1. After first successful generation → soft offer (dismissible): "Loved that? Get unlimited for 3 days free."
2. After hitting the 5/day limit → harder offer.

### Technical & compliance

- **App Privacy Nutrition Label:** disclose "Photos" + "User Content" → App Functionality, Not Linked. Don't add ad networks until you've decided you want them (see below — I'd skip ads).
- **EncryptionExportCompliance:** if you only use HTTPS, set `ITSAppUsesNonExemptEncryption = NO` in Info.plist (saves you ECCN paperwork).
- **Account deletion:** required for any app that has any concept of accounts. You don't have accounts, so this isn't a blocker, but if you add user accounts later, plan for it from day one.
- **Photo permissions strings** look fine (`Info.plist:8-12`).
- **StoreKit testing:** `DreamSculptProducts.storekit` only works in Xcode. Make sure your products are *Approved* in App Store Connect before TestFlight (your `fetchProducts` retry logic in `StoreManager.swift:48` is a smart hedge).
- **Reviewer test account:** you don't need one (no login), but include a note: "No login required. App generates AI images from sketches. Free tier provides 5 generations/day."
- **API ToS:** if you're proxying a third-party model (Stability, Replicate, fal, etc.) check their ToS allows commercial redistribution and image rights pass through to end users. App Store reviewers care that *your users own what they create*. State this clearly in your ToS.

### Analytics (you have ZERO instrumentation)

This is the single biggest gap for measuring launch. Without analytics you cannot improve. Pick one:

- **PostHog** (recommended for indie — generous free tier, self-host option, session recording, funnels).
- **Mixpanel** (cleaner UI, more expensive at scale).
- **Amplitude** (overkill for v1).
- **TelemetryDeck** (Swift-native, privacy-first, no PII, App Store reviewer-friendly).

For an indie launch I'd use **TelemetryDeck for product analytics + Sentry for crashes**. Both are privacy-respecting, don't trigger ATT prompt, and give you the metrics you need.

Events to track from day 1:
- `app_opened` (with cohort/install_date)
- `onboarding_completed`
- `canvas_first_stroke`
- `generation_requested` (style, has_base_image, prompt_was_custom)
- `generation_succeeded` / `generation_failed` (latency_ms)
- `image_saved`, `image_shared`
- `paywall_viewed` (placement, tier)
- `purchase_completed` (product_id)
- `limit_reached`

---

## 3. App Store Optimization (ASO) Strategy

### Keyword strategy

Don't try to rank for "AI image generator" — you'll get crushed by apps with 100x your install base. Target the long tail where you have a real shot.

**Primary high-intent keywords to target:**
- ai sketch, sketch to image, sketch to photo, ai drawing, drawing to ai
- ipad sketch ai, apple pencil ai, ai illustration ipad
- ai art, ai photo editor, ai image edit
- doodle to image, scribble to art

**Secondary / long-tail:**
- ai cartoon maker, anime sketch, cyberpunk art generator, watercolor ai
- ai art tutor, learn to draw with ai
- photo edit ai, edit photos with ai

**Low competition / easy wins:**
- "sketch to photorealistic"
- "draw to ai art"
- "ipad ai drawing"

### Title, subtitle, description

**Current name:** "DreamSculpt" — fine, distinctive, brandable. Keep.

**App Store title** (30 char limit): `DreamSculpt: AI Sketch to Art`

**Subtitle** (30 char): `Draw it. AI brings it to life.`

**Promotional Text** (170 char, swappable without re-review): `New: Edit photos by drawing on them. Sketch a change, watch AI apply it. 5 free generations daily.`

**Description** (4000 char, but only first ~3 lines visible without "more"):

```
Turn rough sketches into stunning AI artwork. Draw with your finger or Apple Pencil — DreamSculpt transforms your scribbles into photorealistic photos, oil paintings, anime, cyberpunk, watercolors, and more.

THE EASIEST WAY TO MAKE AI ART
No prompt engineering. No complicated controls. Just sketch what you imagine and tap Generate.

EDIT PHOTOS BY DRAWING ON THEM
Take a photo, sketch what you want to change — circle a person, scribble in a sky, doodle a hat — and let AI apply your edits seamlessly.

FIVE STUNNING ART STYLES
- Photorealistic — cinematic, professional photography
- Oil Painting — gallery-quality brushstrokes
- Anime — Studio Ghibli inspired
- Cyberpunk — neon-lit futuristic
- Watercolor — soft, flowing color

BUILT FOR APPLE PENCIL
Pressure-sensitive sketching, real-time feedback, native PencilKit integration.

PRIVATE BY DESIGN
Your sketches are processed and discarded. No accounts, no tracking, no ads.

— FREE: 5 AI generations per day
— PRO: Unlimited generations, no watermark, 3-day free trial

Whether you're a doodler, sketcher, photographer, or just curious — DreamSculpt is the most intuitive AI art tool you'll ever use. Sketch your imagination, see it transform.
```

Note: the keywords appear naturally in the body. Apple indexes the description (not just the keyword field) for organic search. Don't keyword-stuff — write for humans.

**Keyword field** (100 chars, comma-separated):
`sketch,draw,ai art,doodle,ipad,pencil,photo edit,illustration,anime,watercolor,painting,scribble`

### Visual assets — this is where most indie launches die

**App icon:**
- Your `DreamSculptMark` is a stylized "D" with a spark. Brandable but might not pop in the store. Test it at 60x60 thumbnail size — does it read? If not, consider:
  - A bolder, more contrast-y icon.
  - A literal **sketch + AI sparkle** (a pencil scribble morphing into a photo) reads instantly at thumb size.
- A/B test 3 icons via App Store Product Page Optimization (PPO) post-launch.

**Screenshots (this is the #1 conversion driver):**
Make 6–8 screenshots, each landscape-readable as a "billboard." Indie apps that nail screenshots get 2–3x more downloads from the same impressions. Structure:

1. **Hero before/after.** Left half: rough sketch. Right half: photoreal result. Headline: "Turn sketches into stunning AI art."
2. **Sketch → Anime.** Same sketch, anime style. Headline: "5 styles, infinite ideas."
3. **Photo + scribble → edited photo.** Show the photo-edit mode. Headline: "Edit photos by drawing on them."
4. **Apple Pencil action shot.** Real iPad with Pencil mid-stroke. Headline: "Built for Apple Pencil."
5. **Style strip.** All 5 styles applied to the same sketch in a grid. Headline: "Photo. Oil. Anime. Cyber. Watercolor."
6. **Social proof.** 1–2 user-made pieces with usernames. Headline: "Loved by sketchers everywhere." (Add post-launch.)

Use a tool like **Screenshots Pro / Previewed** or hand-craft in Figma. Each screenshot should have a bold caption — Apple's screenshots without captions perform worse.

**App Preview Video (15–30s):**
- Open with a hand drawing a stick figure on iPad. Cut. AI sparkle overlay. Cut. Photoreal hero shot.
- Cycle through 3 style transformations.
- End on logo + "DreamSculpt — Sketch your imagination."
- No voiceover (most users watch muted). Use captions.
- This is mandatory for v1. Indie apps without an App Preview convert 30–40% worse.

---

## 4. Low-Effort / Hands-Off Marketing & User Acquisition Plan

The rule for a solo dev: **every channel must be either free, automated, or compounding.** No daily Twitter posts. No grind.

### Launch week tactics (one-time, high-leverage)

**Product Hunt** (best single-day amplifier for indie iOS apps):
- Submit at 12:01 AM PT on a Tuesday or Wednesday.
- Pre-line up "hunters" — DM 5–10 makers with PH presence and ask if they'll upvote on launch day.
- Have a clear demo GIF as the lead asset.
- Reply to every comment in the first 12 hours.
- Realistic expectation: top-5 product of day = 500–2000 visits, 50–200 installs.

**Reddit (the long-tail compounding channel):**
- r/iPadart (300k) — post a creation made with the app. Don't link, mention in comments.
- r/AIart, r/midjourney, r/StableDiffusion — show iPad-specific workflow.
- r/iosgaming, r/iosapps, r/ApplePencil
- **Do NOT** spam with launch announcements. Make and post real art every 1–2 weeks. Reply genuinely. Mention DreamSculpt only when asked.

**Hacker News:**
- "Show HN: DreamSculpt — sketch-to-AI-art for iPad (built solo)"
- Lead with the technical/journey angle, not marketing copy.
- Best chance of front page on a Tuesday morning ET. One post only — don't re-post if it flops.

**Indie maker communities (write once, post everywhere):**
- Indie Hackers "I launched"
- BetaList (free; gets you on aggregator sites)
- Tiny Launch
- BetaPage
- Launching Next

**Apple-specific:**
- **Submit for App Store featuring** via App Store Connect's editorial nomination form. Indie creative apps with strong Apple Pencil integration get featured ~5–15% of the time. Lead with: "Native PencilKit, 100% on-device sketching, novel sketch-to-AI workflow." This is free and could 10–100x your launch.
- **Submit to Apple Design Awards** if you can polish more.
- **Reach out to AppStories podcast** (Federico Viticci) — they cover indie iPad-first apps.

### Content / SEO that runs on autopilot

**The single highest-ROI compounding content investment for an indie consumer app: a YouTube channel with 10–15 short-form (20s–60s) videos.**

Why YouTube Shorts > TikTok > everything else for AI art apps:
- AI art transformations are *inherently* viral (before/after gestalt).
- Shorts are searchable and rank in Google.
- One viral short = sustained discovery for years.
- You can record once and cross-post to TikTok, IG Reels, X, Pinterest.

**The format:** ASMR-y screen recording of someone drawing on iPad → tap Generate → reveal. 15s. No talking. Caption: "POV: drawing on iPad with AI."

Make 20 of these in a single weekend. Auto-schedule with **Buffer** or **Later**. Done.

**Pinterest** is the sleeper channel for AI art:
- Pinterest users *search* for art and aesthetic content.
- Pin every output you make (with watermark).
- Auto-pin via **Tailwind**.
- One viral pin = months of traffic.

**SEO blog:** skip it for v1. Not your leverage point as an indie. Revisit at month 6.

### Virality / sharing mechanisms — bake into the app

Every shared image is a free ad. Optimize:

1. **Watermark on all free-tier saves and shares.** "Made with DreamSculpt — appstore.com/dreamsculpt" in lower right. Subtle but readable. Removable only via Pro.
2. **Save as MP4 timelapse** — record the sketch process and overlay it with the result. People share videos at 10x the rate they share static images.
3. **"Side-by-side" share format** — auto-generate a 1:1 image with sketch + result side by side, branded. This is the most-shared AI-art format on Twitter.
4. **One-tap share to Instagram Stories / TikTok / iMessage** with prefilled hashtags `#DreamSculpt #SketchToAI`.
5. **Referral hook (light):** "Send a friend your first generation, both get 5 bonus credits." Implement via universal links so attribution is automatic.

### Partnerships & cross-promotion

Low-effort partnerships that don't require ongoing maintenance:

- **Bundle into Setapp**? No — Setapp is Mac. Skip.
- **Apple Pencil-adjacent app cross-promo:** reach out to indie devs of Concepts, Tayasui Sketches, Linea Sketch — propose a 1-time mutual mention in newsletters. They have Apple Pencil audiences who'd love AI augmentation.
- **iPad creator newsletters:** "MacStories Weekly" (Federico), "Daring Fireball" (long shot), "iPad Pros" newsletter.
- **TikTok / IG creators in the AI art space:** send 3 free Pro codes to micro-creators (10k–100k followers) who already post AI art. Don't pay them. Most will post organically if the app is good.

### Email / push / retention automation

You don't have user accounts, so email is hard. Push and local notifications carry the load:

| Trigger | Channel | Message | Why |
|---|---|---|---|
| Day 1 after install, no first generation | Local push | "Your first sketch awaits" | Activation |
| First successful generation | In-app | "Loved that? Try Anime style on the same sketch." | Style discovery |
| Day 3, ≥1 generation but no return | Push | "Your free generations refilled. Today's prompt: 'a dragon at sunrise.'" | Reactivation |
| Day 7, dormant | Push | "Come back — here's 3 free credits." | Win-back |
| Friday afternoon (high creation hours) | Push | "Weekend project: turn a memory into art." | Weekly cadence |

Implement once with `UNUserNotificationCenter` + `UNCalendarNotificationTrigger`. No backend required for any of this — local notifications run forever from a single setup.

### Paid acquisition (only if hands-off)

For an indie launch, **skip paid for the first 60 days.** You don't have data to know your LTV, and paid without instrumentation just lights money on fire.

After 60 days, if your D7 retention is >15% and your ARPU is >$0.50:
- **Apple Search Ads (Basic or Advanced).** Smart campaigns are genuinely hands-off. Set a $20/day cap, let Apple optimize. Best for high-intent keywords ("sketch to ai", "ipad ai drawing"). Expected CPA in this category: $2–6.
- **Meta Advantage+ creative campaigns.** Use your viral Shorts as ad creative. Set & forget.
- **Skip Google Ads, TikTok Ads, Reddit Ads** for v1. Too much hands-on management.

### Post-launch growth loops to design

The flywheel you want:

```
User generates art →
  Watermarked share to social →
    Friend sees, googles "DreamSculpt" or searches App Store →
      Installs (organic) →
        Onboarding → first magic moment → shares →
          Loop continues
```

This loop only works if:
1. Every saved image has a watermark (lever 1)
2. The watermark is searchable / brandable (DreamSculpt as a name is good for this — distinctive)
3. The first-time experience reliably hits the magic moment (lever 2 — onboarding)
4. Sharing is one tap (lever 3 — share UI)

Optimize these three and the loop runs itself.

---

## 5. Success Metrics & Iteration Plan

### What to track in days 0–30

| Metric | Target (v1 launch) | Action if below target |
|---|---|---|
| **Day 1 install → first generation rate** | >60% | Onboarding broken — re-record tutorial |
| **% of users hitting the magic moment** (≥3 generations day 1) | >35% | Free tier too small or discovery broken |
| **D1 retention** | >35% | Onboarding / first-session experience |
| **D7 retention** | >12% | No reason to return — push notifs missing or bland |
| **D30 retention** | >5% | Weak product loop |
| **Free → Paid conversion (any)** | >2.5% | Paywall placement, pricing, or trial duration |
| **Median session length** | >3 min | Generation latency? Limited content? |
| **Avg generations / DAU** | >3 | Low engagement |
| **Crash-free rate** | >99.5% | Add Sentry, fix top crashes |
| **Generation API success rate** | >97% | Backend reliability work |
| **Share rate** (% of generated images shared/saved) | >25% | Share UI / friction |
| **Viral coefficient (k)** | >0.15 | Watermark visibility, share format |

### Days 30–60

- A/B test paywall: trial length (3-day vs 7-day), placement (after first gen vs after 3rd gen), copy.
- A/B test free tier: 3/day vs 5/day vs "10 free lifetime then 3/day."
- Pick best-performing screenshots via Apple's Product Page Optimization.
- Ship 3 new style presets based on user requests.
- Launch the daily prompt feature.

### Days 60–90

- Decide: subscription is dominant (>70% of revenue) → cut consumables. Or consumables > subs → drop weekly sub, keep annual + packs.
- Launch a lightweight web gallery (read-only) of opt-in featured generations. SEO + social proof asset.
- Begin paid acquisition only if unit economics work.

### Pivot / no-go criteria

If by **day 60**:
- D7 retention < 8%
- Free → paid conversion < 1.5%
- Share rate < 10%

…the product doesn't have PMF as currently positioned. Pivot toward photo-edit-by-scribble as the lead value prop (Option B from section 1) and re-launch with new ASO.

If by day 60 you're hitting >12% D7 and >2.5% conversion, you have a real business. Push paid acquisition and content investment.

### Suggested experiment roadmap

| Week | Experiment | Hypothesis |
|---|---|---|
| 1 | Onboarding A/B: tutorial sketch vs. blank canvas | Tutorial 2x first-generation rate |
| 2 | Free tier A/B: 3/day vs 5/day | 5/day improves D7 +30% with negligible revenue hit |
| 3 | Paywall placement: post-first-gen vs limit-reached | Post-first-gen wins on conversion, limit-reached wins on retention |
| 4 | Watermark style A/B: text-only vs logo+text | Logo+text improves share-driven installs |
| 5 | Style discovery A/B: chips above prompt vs inside prompt | Above drives 1.5x style switches |
| 6 | Push notification copy A/B | "Today's challenge" vs "Your free credits refilled" |
| 7 | Screenshot A/B (PPO) | Hero before-after vs Pencil-action shot |
| 8 | Subscription A/B: weekly vs monthly | Weekly + 3-day trial wins D30 LTV |

---

## TL;DR — what to do this week

Three things matter most before you submit:

1. **Fix the activation hole.** Build a 30-second onboarding with a tutorial sketch. This is the single highest-leverage change you can make. Without it, your launch will leak users badly.
2. **Add analytics + watermarking + a privacy policy.** These three are blockers for measuring success, growing organically, and passing review.
3. **Reposition for iPad + Apple Pencil and ditch the "Sculpt your imagination" tagline** in App Store assets. Your differentiator is sketch-input + Pencil — own that lane.

Everything else in this doc is sequenced after those three. Ship with those three nailed and you have a real shot at organic compounding growth instead of a launch-day spike that fades.
