# Pastor Onboarding v2 — "Claim your church" flow

Interactive design prototype for the rebuilt pastors.ygteev.com signup.
**Open `index.html` in any browser** (no build, fully self-contained; use the
numbered dots bottom-right to jump between steps, or `#step=N` in the URL).

Replaces the 8-step wizard with **4 screens, ~2 minutes, phone-first**:

| # | Screen | What happens |
|---|---|---|
| 1 | **Account** | Apple / Google one-tap, or church email + password. Live hint: branded church email = instant verification later. |
| 2 | **Find your church** | Search the **church** (not the youth group) via Google Places. Discovered churches show an "ON YGTEEV" badge → tapping reveals the **claim card** with the branding we already scraped (logo, bio, Instagram) — the "we already made your page" moment. Unknown churches get a create card pre-seeded from the Places result. Then: group name (prefilled) + student-count chips that double as tier selection. |
| 3 | **Payment** | Tier summary, "$0.00 due today", 14-day trial badge → Stripe Checkout (Apple Pay on phones). |
| 4 | **Launch** | Confetti. Two states: **verified** (branded email → officially claimed, public) or **unverified** (personal email → group live privately; amber "Verify to go public" card with 6-digit code to any inbox at the church's domain, or manual review). Always: App Store button, student invite link, "finish your look later". |

## Verification model (the important design decision)

Verification gates **publicity, not payment**:

- The email check is **two-stage**: screen 1 shows a soft hint ("looks like a
  church email") since the church isn't known yet; screen 2, once the church is
  selected, renders the definitive verdict by comparing the email domain to the
  church's website domain (match / mismatch / no-domain states).
- Branded email (`@elevationchurch.org`) → the standard account-confirmation
  email doubles as the claim proof. Group goes public immediately.
- Personal email (gmail etc.) → signup + payment proceed normally; the group
  works privately (QR invites, chat, plans, garden). The public map pin and
  the "claimed" link on a `discovered_youth_groups` row are held until either:
  - a 6-digit code sent to any inbox at the church's website domain, or
  - admin manual review (CMS queue via the existing `needs_review` flag).
- Sign in with Apple hides emails behind relays → those users always use the
  code/review path (screen 1 hints "use your church email").

## Backend wiring (for the Lovable build)

| Prototype element | Production source |
|---|---|
| Church search | Google Places Autocomplete (type=church) with **locationBias to the user's area** — IP-based by default, upgraded to precise browser geolocation if granted. The "📍 Searching near {city} · change" chip shows the bias and lets them override the city (pastors signing up from home/away still find their church). Results show distance. Result gives name/address/lat/lng/**website** in one tap. |
| "ON YGTEEV" badge + claim card | Match Places result → `discovered_youth_groups` (geo proximity + name similarity; **add a `place_id` column** and backfill on every match). Card fields: `logo_url`, `hero_url`, `instagram_handle`, `short_description`, `name`. |
| Student-count chips | `subscription_tiers` (labels + `price_cents`) — replaces the pricing slider. |
| Draft persistence | `pastor_signup_drafts` — unchanged; partial-save per screen, resume + reminder emails already exist. |
| Checkout | `create-checkout-session(draft_id, tier_id, success_url, cancel_url, promo_code?)` — unchanged. |
| Finalize | `stripe-webhook` → `finalize_pastor_signup`. **Needs**: link `discovered_youth_groups.linked_youth_group_id`, copy scraped branding into the new group, default `group_type` + `description` (iOS map silently hides groups missing either). |
| Domain verification | New: `claim_verifications` table + edge function to send/check the 6-digit code (Resend). Compare registrable domains (strip www/subdomains). Admin-managed extra-domains list per church for multi-domain cases. |
| Public visibility | New `verification_status` on `youth_groups` gating `is_public`. |

## Deliberately cut from the old flow

Feature-tour screens (4), branding step (logo/gradient/description), meeting
day/time, pricing slider. All deferred to the landing page or the iOS app.
Landing-page copy fix needed: "No credit card to start" contradicts
`payment_method_collection: always` — change to "14-day free trial · cancel anytime".
