# Lovable prompt — Pastor Onboarding v2 ("Claim your church")

> Paste everything below the line into Lovable, and **attach
> `pastor-onboarding-v3/index.html`** as the visual spec. That single HTML file
> is the pixel-level source of truth — colors, spacing, motion, and copy.
> Also needed: a Google Maps Platform API key with **Places API** enabled
> (set as a Lovable env var, e.g. `VITE_GOOGLE_PLACES_KEY`).

---

Rebuild the signup wizard at `/create` on pastors.ygteev.com. Keep the landing
page, sign-in, and the pastor dashboard exactly as they are — this replaces
ONLY the create flow. The attached `index.html` is an interactive prototype of
the target design: a clean, high-converting B2B onboarding in the style of
ElevenLabs/Stripe — near-white background (#fafafa), Inter, hairline borders
(#e6e6ea), white cards with soft shadows, black primary buttons, one green
accent for positive states and amber for the verify card. NO gradients, NO
dark theme, minimal motion (screen slides, a pin-drop on the map, one
checkmark pop). Thin black progress bar + "Step N of 4" top right. Click through it with
the numbered dots before building. Drop the numbered dev dots — they're
prototype chrome.

The flow is **4 screens on one page** (slide transitions, `#step=N` deep
links), phone-first (max-width 430px column), with partial-save to
`pastor_signup_drafts` after every screen so abandoned signups resume.

## Screen 1 — Account

- "Continue with Apple" / "Continue with Google" (Supabase OAuth), or church
  email + password (Supabase signUp).
- Under the email field, a live hint chip: if the typed domain is NOT a free
  provider (gmail/yahoo/icloud/outlook/hotmail/aol/me), show green
  "✓ Looks like a church email — we'll confirm it matches your church";
  free provider → dim "Personal email works too — you can verify your church
  later"; empty → dim "Use your church email — your group gets verified
  instantly". This is a soft hint only — the real check happens on screen 2.
- Create/refresh the `pastor_signup_drafts` row (email, first_name, user_id).

## Screen 2 — Find your church

- Headline "Find your church." / "Search the church, not the youth group —
  we'll handle the rest."
- **Church name search** (Google Places Autocomplete, church/establishment
  types) with a **ZIP field** beside it. Location bias: IP-derived by default;
  a chip under the field shows "📍 Searching near {city} · change" — tapping
  *change* swaps the chip for an inline City-or-ZIP input (Enter or Set
  applies; a 5-digit value also fills the ZIP field). Typing a ZIP re-biases
  the search. Each result row shows distance + address. Always append a
  dashed "Can't find your church? Enter it manually — we'll review & verify
  it." row (manual entry = free-text church name/address/city → geocode; the
  group will use the manual-review verification path).
- On selection, resolve Place Details (name, formatted_address, lat/lng,
  **website**) and try to match a row in `discovered_youth_groups`:
  1. exact `place_id` match, else
  2. within ~300m of lat/lng AND similar name (church_name or name), case
     insensitive.
  When matched, write the Place's `place_id` back onto that row (backfill).
- **Matched (claim card)**: heading becomes "We found your group" / "Our
  system already built a profile for your youth group. Confirm it's yours."
  White bordered card: `logo_url` tile (fallback: initial on a dark tile),
  `name` (e.g. "Elevation YTH"), church name · `instagram_handle`,
  `short_description` as a left-bordered quote, green badge "✓ Profile ready —
  logo, bio & map pin".
- **No match (create card)**: heading "Confirm your church"; card with church
  name, address, green badge "✓ Address & map pin filled from your search".
  CTA: "Create my group".
- Both cards include the **map confirmation**: light map tile with an
  animated pin drop, pulsing radius ring, and a "✓ LOCATED · {address}" bar
  (see prototype).
- Below the card: the **definitive email verdict chip** — compare the
  account's email domain to the church website's registrable domain (strip
  www/subdomains): match → green "✓ Your email matches @{domain} — verified
  the moment you claim"; branded-but-different → dim "Your email
  (@{their-domain}) doesn't match @{domain} — quick verify after checkout";
  free-mail/no-domain → dim "You'll verify @{domain} after checkout — or
  request a review".
- **Group name** input, prefilled: discovered `name` if matched, else
  "{Church-without-'Church'} Youth".
- **"About how many students?"** — 5 tap chips from `subscription_tiers`
  (range_label + $price/mo from price_cents), 2-col grid of white radio
  cards; the selected card gets a black border. This IS the tier selection —
  no slider.
- The screen's CTA (both claim and create cases) is the offer: **"Start
  your 90-day free trial"**, with a dynamic subline once a size is picked:
  "No charge today · then ${price}/mo". Disabled until a size is selected.
- Save to draft: church_name, address_line, address_city, latitude,
  longitude, place_id, discovered_id, church_domain, church_website,
  group_name, tier_id.

## Screen 3 — Payment

- "Start your free trial" / "Every student in your group gets Pro —
  included in your plan."
- Green notice "✓ 3 months free, then your plan price. Cancel anytime."
  Order-summary card: group name + "{range} students" · "After your trial
  **${price}/mo**" · "Due today **$0.00**" (green). Trust row: " Pay ·
  Stripe · PCI-DSS compliant".
- CTA "Continue to secure checkout →" calls the `create-checkout-session`
  edge function `{ draft_id, tier_id, success_url, cancel_url, promo_code? }`
  and redirects to the returned `url`. The server already defaults to a
  **90-day trial**. success_url → `/create#step=4`; cancel_url →
  `/create#step=3`.
- Footnote: "Free until {date +90d} — we'll remind you before it ends."

## Screen 4 — Launch (Stripe success return)

The `stripe-webhook` finalizes everything server-side (creates the group,
memberships, welcome email). Poll the draft until `finalized_youth_group_id`
is set, then read the group's `verification_status`.

- Green checkmark pop (no confetti). Headline "{Group name} is live".
- **verified** (branded email matched at finalize): sub "Officially claimed
  and on the map. Now put it in your students' hands." No verify card.
- **pending**: sub "Your students can join today — one step left to go
  public." Amber card "⚠ Verify to go public": explains the group works for
  invited students, but the public map pin waits for a code sent to any inbox
  `@{church_domain}`. Input for the inbox local-part or full address + a
  6-box code entry (auto-advance, backspace-jumps-back). Wire:
  - Send: `send-claim-code` edge function `{ group_id, send_to }` (errors:
    `address_not_at_church_domain`, `rate_limited`, `no_church_domain` →
    show "request manual review" as the fallback link, which flags the group
    for admin review).
  - Check: rpc `verify_claim_code(_group_id, _code)` → `{ok:true}` flips the
    group public; re-render as the verified state with a small celebration.
- Always: three bordered action rows — **Download the app** (App Store
  button; signing in with this account lands them as pastor), **Invite your
  students** (`ygteev.com/j/{slug}` + Copy link), **Finish your profile**
  (logo, meeting time & bio — "later, in the app").

## Backend contract (already deployed — do NOT create tables or functions)

- `pastor_signup_drafts` — has all columns above incl. place_id,
  discovered_id, church_domain, church_website.
- `discovered_youth_groups` — read for claim cards; write only `place_id`.
- `subscription_tiers` — read (labels/prices); never hardcode prices.
- `create-checkout-session`, `send-claim-code` edge functions;
  `verify_claim_code` RPC; `stripe-webhook` + `finalize_pastor_signup` run
  server-side untouched.
- Trust footer everywhere: "Built by people who run youth groups · Your data
  is yours".

Also update the landing page's trial copy wherever it appears: replace
"14-day free trial" / "No credit card to start" with **"3 months free ·
cancel anytime"** (a card IS collected at checkout).
