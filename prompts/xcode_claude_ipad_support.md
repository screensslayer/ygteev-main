# Xcode-Claude prompt — Native iPad support (phased, low-risk)

> Paste everything below the line into xcode-claude, run it in the YGTeeV
> project. Phase 1 is one sitting; don't start Phase 2 until Phase 1 builds
> and looks right in the iPad simulator.

---

Add native iPad support to YGTeeV. The app is currently iPhone-only
(`TARGETED_DEVICE_FAMILY = 1`) and pure SwiftUI (iOS 17, TabView shell in
`MainTabView.swift`). There are ~365 usages of `UIScreen.main.bounds` and
fixed `.frame(width:)` across the codebase, so DO NOT attempt a per-screen
iPad redesign — use the width-capped strategy below, which makes phone
layouts look intentional on iPad without touching hundreds of views.

## Phase 1 — enable iPad with a width-capped root

1. In the YGTeeV target, set `TARGETED_DEVICE_FAMILY = 1,2` (all build
   configurations).
2. Add `UIRequiresFullScreen = YES` to Info.plist and support all four
   orientations on iPad (`UISupportedInterfaceOrientations~ipad` with all
   values). Full-screen-required exempts us from Split View/Slide Over
   resizing, which the fixed-width code can't survive yet.
3. Create a `ReadableWidthContainer` ViewModifier: on regular-width size
   classes it constrains content to `maxWidth: 620` centered, with the
   app's background color filling the letterbox; on compact width it's a
   no-op. Apply it ONCE at the root (around the TabView in
   `MainTabView.swift` and around any full-screen covers/sheets presented
   from the app root, including onboarding). Do not apply it per-screen.
4. Exceptions that should stay full-bleed edge-to-edge on iPad (do NOT
   width-cap these):
   - `BackyardGameView` (WKWebView game — the web game handles its own
     responsive layout)
   - Any full-screen video players
   - The map view(s) (`JoinGroupMapView`, `LockedRadiusMapView`, home map)
     — maps look wrong letterboxed; let them fill.
5. `UIScreen.main.bounds` sweep — do NOT rewrite all of them. Only fix the
   ones that break under the width cap: grep for `UIScreen.main.bounds`
   and `.frame(width:` and fix any usage that sizes CONTENT relative to
   the full screen (those will overflow the 620pt cap on iPad). Replace
   with `GeometryReader`/container-relative sizing. Leave usages that
   position overlays/absolute effects alone if they render correctly.
6. Launch screen: confirm it renders correctly on iPad (storyboard/
   generated launch screens usually just work).

Build and run on: iPad Pro 13" (portrait + landscape), iPad mini, and
regression-check iPhone 15 Pro. Screenshot each tab on iPad and fix
anything visually broken before calling Phase 1 done. Commit as its own
commit.

## Phase 2 — targeted iPad polish (separate sitting, after Phase 1 ships)

Only after Phase 1 is stable, upgrade the highest-value screens to
actually use iPad space (keep everything else width-capped):

1. Home feed: on regular width, 2-column grid for feed cards.
2. Bible reading (`DailyPlanView`): raise the reading column to ~700pt
   and bump type size — reading is the killer iPad use case.
3. Chat: consider `NavigationSplitView` (thread list | conversation) on
   regular width only; keep the stack on iPhone.
4. Backyard game: none — the web game already adapts (portrait camera
   zoom is web-side).

## Do NOT

- Do not remove `UIRequiresFullScreen` (Split View support is a later
  project).
- Do not change any backend calls, entitlements, or the WKWebView embed
  contract (token hash handoff).
- Do not redesign screens beyond the listed Phase 2 items.

## Reminder for the human (not xcode-claude)

App Store Connect will require **iPad screenshots (13" class)** on the
next submission once the binary declares iPad support. Take them from the
iPad Pro 13" simulator after Phase 1.
