# YGTeeV Pastor Onboarding — Design Bundle

Canonical design source for the public pastor signup flow at `ygteev.com/youthgroups`.

These files were authored in Claude Design (claude.ai/design) and exported as the
reference spec for the Lovable build. **Treat them as source-of-truth for visual
fidelity** — exact colors, animations, spacing, and copy.

## Files

- `YGTeeV Pastor Onboarding.html` — entry point; loads the 3 JSX modules.
- `pastor-flow.jsx` — wizard shell: 11-step state machine, design tokens,
  shared primitives (`CTA`, `ProgressBar`, `TopBar`, `Surface`, `TrustFooter`,
  `MapPin`, `Mark`). Exposes the `STEPS` array and `useAppState` hook.
- `pastor-screens.jsx` — Screens 0–3: Landing, Create Account, Group Location,
  Brand Your Group.
- `pastor-screens-2.jsx` — Screens 4–10: Tours (Small Groups, Safe Chat, Events,
  Bible+Garden), Pricing slider, Checkout placeholder, Welcome / confetti.
- `brand.css` — design tokens (colors, type, glass utilities).

## How to open it locally

```bash
cd pastor-onboarding-design
python3 -m http.server 8000
# Open http://localhost:8000/YGTeeV%20Pastor%20Onboarding.html
```

Each screen is reachable directly via the URL fragment `#step=N` (0–10).

## Implementation target

The production version is built in **Lovable** (React + Supabase). Lovable's
build prompt is in the project root chat — it references these files as the
visual spec.

## What changes from prototype → production

| Concern | Prototype (here) | Production (Lovable) |
|---|---|---|
| State | Local `useState`, mock data | Supabase `pastor_signup_drafts` table; partial-save on every step |
| Address | Free text | Mapbox Address Autofill |
| Auth | Mocked "Create account" CTA | Supabase Auth signUp + Apple / Google OAuth |
| Logo upload | Hardcoded initials | Real upload to `youth-group-logos` bucket |
| Pricing tiers | Hardcoded `TIERS` array | Backend `subscription_tiers` table |
| Stripe checkout | Placeholder card | Real Stripe Checkout session redirect |
| Welcome → "dashboard" | Empty buttons | Real route to `/youth-groups/:id` in CMS |

## Don't modify these files

If the design changes, regenerate the bundle from Claude Design and replace.
Treat the JSX as documentation, not an editable codebase.
