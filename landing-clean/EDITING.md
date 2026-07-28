# Editing the landing page copy

Everything is in `index.html` — one file, no build step. Open it, edit text, save,
refresh the browser. The rule of thumb: **change words between `>` and `<`, never
the tags/classes/ids around them.**

Fastest method: copy a phrase you see on the page, Cmd+F for it in `index.html`,
edit it in place.

## Where each section's copy lives

Sections appear in the file in page order. Search for the `id=` to jump there.

| Section | Search for | What's there |
|---|---|---|
| Top nav | `class="topnav"` | Nav labels (Safety, The game, League, Platform) |
| Hero | `id="hero"` | Eyebrow, headline (3 lines, last one green), paragraph, button labels, "Free for 90 days" line |
| Trust strip | `class="hero-proof"` | The four bullet facts under the hero |
| Hero dashboard mockup | `Wednesday Night Youth` | All the fake dashboard data (names, numbers, streaks) |
| Safe chat | `id="product"` | Headline, paragraph, the four bold bullets, chat mockup messages |
| The game | `id="game"` | Headline, paragraph, three feature rows, phone mockup labels |
| League | `id="league"` | Headline, paragraph, three stats, leaderboard team names/scores |
| Platform | `id="platform"` | Headline, paragraph, the six capability cards |
| Final CTA | `id="cta"` | Headline, paragraph, button labels, three dot-points, QR card text |
| Footer | `id="footer"` | Tagline, link labels |

## Structure of a typical block

```html
<p class="eyebrow">Safe chat</p>                 <- small green label
<h2>Every message is screened ...</h2>           <- section headline
<p class="lede">AI moderation screens ...</p>    <- paragraph under it
```

Edit the words; leave `class="..."` alone.

## Things not to break

- **Section ids** (`id="hero"` etc.) — nav links and tracking depend on them.
- **CTA links** — every button points to
  `https://pastors.ygteev.com/youth-group-registration` and has an `onclick="fbq..."`
  tracker. Change the label text freely; keep the href/onclick.
- **No emojis** — the whole design bar depends on it.
- **`<br class="hbr">`** in the hero headline — those set the three-line break.
  If you rewrite the headline, keep two of them (or delete all of them and let it
  wrap naturally).
- The `<head>` social tags (og:title etc.) — update these if you change the
  headline, so link previews match.

## Removing or reordering a section

Each section is a self-contained `<section id="...">...</section>` block
(footer is `<footer id="footer">`). Delete or move the whole block. If you remove
one, also remove its nav link in `class="topnav"` and its footer link.

## Seeing your changes

- Locally: the file is served at http://localhost:8090/index.html while the
  preview server is running (any static server works).
- Live: deploying to launch.ygteev.com is a git push — ask Claude to deploy the
  updated page.

Or just tell Claude what to change in plain English — it's a one-file edit.
