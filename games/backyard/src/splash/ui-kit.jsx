// Backyard menu design language — "carved stone & warm wood" kit, v2.
// Every component renders REAL art sliced from the approved mockup
// (public/ui/kit/*, built by tools/build-splash-assets.py). Stretchable
// pieces use CSS border-image 3-slice with the painted ends preserved;
// text/numbers/avatars are live DOM layered on top.
//
// Assets are 2x the mockup's pixels; the mockup is a ~2x phone shot, so
// on-screen pt sizes ≈ assetPx / 4 at the reference layout width.

import React from "react";

export const T = {
  font: `"Baloo 2", "Trebuchet MS", system-ui, sans-serif`,
  cream: "#f7ead1",
  carve: "#6d5233",
  inkDeep: "#5e2f14",
  goldText: "#f7dfa0",
  greenText: "#dcffdc",
  idleText: "#f2e9d4",
  interior: "#dfc9ab",
  interiorDark: "#c9ab86",
};

const KIT = "/ui/kit/";

// Horizontal 3-slice: paints `src` across any width, keeping the painted
// ends. sliceL/R are in ASSET pixels; height in display px.
// overlay=true spans children across the WHOLE element (painted ends
// included) — the element then needs an explicit width from its parent.
// overlay=false keeps children in normal flow, so content sizes the box.
export function NineH({ src, assetW, assetH, sliceL, sliceR, height, style, overlay = true, children }) {
  const k = height / assetH;
  return (
    <div
      style={{
        height,
        borderStyle: "solid",
        borderColor: "transparent",
        borderWidth: `0 ${sliceR * k}px 0 ${sliceL * k}px`,
        borderImage: `url(${KIT}${src}) 0 ${sliceR} 0 ${sliceL} fill stretch`,
        boxSizing: "border-box",
        position: "relative",
        ...style,
      }}
    >
      {overlay ? (
        <div style={{ position: "absolute", top: 0, bottom: 0, left: -sliceL * k, right: -sliceR * k }}>{children}</div>
      ) : (
        <div style={{ position: "relative", height: "100%" }}>{children}</div>
      )}
    </div>
  );
}

// ------------------------------------------------------------ StonePanel
// Chunky stone frame: 4 real corner stones + tiling edge bands + warm
// parchment interior.
export function StonePanel({ style, children, edge = 24, corner = 46 }) {
  const edgeCommon = { position: "absolute", zIndex: 1, pointerEvents: "none" };
  return (
    <div style={{ position: "relative", filter: "drop-shadow(0 14px 30px rgba(25,20,10,.5))", ...style }}>
      {/* interior */}
      <div
        style={{
          position: "absolute",
          inset: edge * 0.45,
          background: `linear-gradient(180deg, ${T.interior}, ${T.interiorDark})`,
          boxShadow: "inset 0 6px 14px rgba(70,45,20,.3), inset 0 -4px 10px rgba(70,45,20,.22)",
        }}
      >
        <div style={{ position: "absolute", inset: 0, backgroundImage: "url(/ui/tex-parchment.png)", backgroundSize: "320px auto", mixBlendMode: "overlay", opacity: 0.22 }} />
        <div style={{ position: "absolute", inset: 0, background: "radial-gradient(ellipse 120% 90% at 50% 30%, rgba(255,244,222,.16), rgba(90,55,25,.10))" }} />
      </div>
      {/* edges — four directional bands, full length edge-to-edge; corners
          render above and cover the crossings. Mockup rails: sides ~12pt,
          top (wood) ~17pt, bottom (gray stone ledge) ~13pt. */}
      <div style={{ ...edgeCommon, top: 0, left: 0, right: 0, height: edge * 0.72, backgroundImage: `url(${KIT}edge-top.png)`, backgroundSize: "100% 100%" }} />
      <div style={{ ...edgeCommon, bottom: 0, left: 0, right: 0, height: edge * 0.55, backgroundImage: `url(${KIT}edge-bottom.png)`, backgroundSize: "100% 100%" }} />
      <div style={{ ...edgeCommon, left: 0, top: 0, bottom: 0, width: edge * 0.5, backgroundImage: `url(${KIT}edge-left.png)`, backgroundSize: "100% 100%" }} />
      <div style={{ ...edgeCommon, right: 0, top: 0, bottom: 0, width: edge * 0.5, backgroundImage: `url(${KIT}edge-right.png)`, backgroundSize: "100% 100%" }} />
      {/* corner stones — negative offsets reproduce the mockup's stone jut
          past the rails; bl/br are taller L-shaped elbows (width scales,
          height stays auto) */}
      <img src={`${KIT}corner-tl.png`} alt="" style={{ ...edgeCommon, zIndex: 2, top: -9, left: -9, width: corner }} />
      <img src={`${KIT}corner-tr.png`} alt="" style={{ ...edgeCommon, zIndex: 2, top: -10, right: -10, width: corner }} />
      <img src={`${KIT}corner-bl.png`} alt="" style={{ ...edgeCommon, zIndex: 2, bottom: -15, left: -11, width: corner * 1.17 }} />
      <img src={`${KIT}corner-br.png`} alt="" style={{ ...edgeCommon, zIndex: 2, bottom: -15, right: -9, width: corner * 1.33 }} />
      {/* content — mockup keeps a tight top gap (tabs sit ~30 design units
          under the top rail) and a slightly deeper bottom inset */}
      <div style={{ position: "relative", zIndex: 3, height: "100%", boxSizing: "border-box", padding: `${edge * 0.68}px ${edge + 6}px ${edge * 0.9}px` }}>{children}</div>
    </div>
  );
}

// ------------------------------------------------------------- StoneSlab
// Renders the approved WEEKLY LEADERBOARD stone sign as-is (lettering is
// carved into the asset — public/ui/kit/header-v3.png (black stone), from
// design-ref/header-sign-v2.png). Fixed aspect; no DOM label.
export function StoneSlab({ style, onClick }) {
  return (
    <img
      src={`${KIT}header-v3.png`}
      alt="Weekly leaderboard"
      role={onClick ? "button" : undefined}
      onClick={onClick}
      draggable={false}
      style={{
        WebkitTapHighlightColor: "transparent",
        display: "block", height: "auto", userSelect: "none",
        filter: "drop-shadow(0 4px 7px rgba(30,25,15,.4))",
        ...style,
      }}
    />
  );
}

// ------------------------------------------------------------- TabToggle
// Approved stone tab slabs with baked labels (public/ui/kit/tab-<key>-v2.png,
// 560x188 each). The selected tab gets a soft green glow behind it.
export function TabToggle({ tabs, active, onChange, style }) {
  return (
    <div style={{ display: "flex", gap: 14, ...style }}>
      {tabs.map((t) => {
        const on = t.key === active;
        return (
          <img
            key={t.key}
            src={`${KIT}tab-${t.key}-v2.png`}
            alt={t.label}
            role="button"
            draggable={false}
            onClick={() => onChange && onChange(t.key)}
            style={{
              flex: 1, minWidth: 0, width: "50%", height: "auto", display: "block",
              cursor: "pointer", WebkitTapHighlightColor: "transparent", userSelect: "none",
              filter: on
                ? "drop-shadow(0 0 6px #7ef0a0) drop-shadow(0 0 14px #57d97fcc) brightness(1.06)"
                : "drop-shadow(0 3px 4px rgba(30,25,15,.35)) brightness(.94) saturate(.92)",
              transition: "filter .22s ease",
            }}
          />
        );
      })}
    </div>
  );
}

// --------------------------------------------------------------- WoodRow
// The approved player plank (public/ui/kit/row-plank-v2.png, 1150x210,
// master design-ref/row-plank-v2.png). One uniform plank for every player:
// blank rank cap, transparent ring hole (live avatar sits BEHIND it),
// open plank field for the name, and a cut-out window for the level.
// The plank asset is CHUNKIER than the mockup's rows (asset 1150x210 =
// 5.48:1; mockup rows ≈ 556x78 design units = 7.1:1). To reproduce the
// mockup's row pitch WITHOUT squashing the painted ring into an ellipse,
// the plank renders at a FIXED height via a horizontal 3-slice
// (border-image): the rank cap + avatar ring (asset x 0..400) and the
// level-window end (asset x 880..1150) keep their painted proportions,
// and only the plain wood-grain middle stretches to fill the width.
// Overlays are therefore positioned in ASSET px * k (k = height/210)
// from whichever end owns them, not in % of the total width.
// `tone` is accepted for API compatibility but unused. `height` is the
// REAL row height in display px (mockup: ~78 design units).
export function WoodRow({ rank, name, score, avatarUrl, tone, me = false, height = 52, style }) {
  const k = height / 210; // asset px -> display px
  const SL = 400, SR = 270; // 3-slice cuts, in asset px
  // "Me" rows ride the light plank (row-plank-me-v2.png, same geometry) and
  // flip to dark ink for contrast on the pale wood.
  const plank = me ? "row-plank-me-v2.png" : "row-plank-v2.png";
  const ink = me ? "#6b4a26" : T.cream;
  const inkShadow = me ? "0 1px 1px rgba(255,244,220,.55)" : "0 1px 2px rgba(40,20,5,.7)";
  return (
    <div
      style={{
        position: "relative", width: "100%", height, flexShrink: 0,
        fontFamily: T.font,
        filter: me
          ? "drop-shadow(0 0 8px #8af2a2aa) drop-shadow(0 2px 4px rgba(30,20,10,.3))"
          : "drop-shadow(0 2px 4px rgba(30,20,10,.3))",
        ...style,
      }}
    >
      {/* avatar disc — UNDER the plank so the painted ring frames it.
          Ring center in asset px: (276.6, 103.2); hole diameter ~136. */}
      <div
        style={{
          position: "absolute", left: 276.6 * k, top: 103.2 * k,
          width: 136 * k, height: 136 * k,
          transform: "translate(-50%,-50%)",
          borderRadius: "50%", overflow: "hidden",
          background: "linear-gradient(180deg,#9fd8ef,#c8ecf7)",
          display: "grid", placeItems: "center", zIndex: 0,
        }}
      >
        {avatarUrl ? (
          <img src={avatarUrl} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        ) : (
          <span style={{ fontWeight: 800, fontSize: height * 0.34, color: "#3c6e8c" }}>
            {(name || "?").slice(0, 1).toUpperCase()}
          </span>
        )}
      </div>

      {/* the plank itself — 3-slice so only the middle grain stretches */}
      <div
        style={{
          position: "absolute", inset: 0, zIndex: 1, pointerEvents: "none",
          borderStyle: "solid", borderColor: "transparent",
          borderWidth: `0 ${SR * k}px 0 ${SL * k}px`,
          borderImage: `url(${KIT}${plank}) 0 ${SR} 0 ${SL} fill stretch`,
        }}
      />

      {/* rank — centered on the cap block (asset x 0..178) */}
      <div
        style={{
          position: "absolute", left: 0, width: 178 * k, top: "8%", bottom: "12%",
          display: "flex", alignItems: "center", justifyContent: "center",
          zIndex: 2, fontWeight: 800, fontSize: height * 0.46, color: ink,
          textShadow: inkShadow,
        }}
      >
        {rank}
      </div>

      {/* name — on the open plank field between ring and level window */}
      <div
        style={{
          position: "absolute", left: 410 * k, right: 290 * k, top: "44%",
          transform: "translateY(-50%)", zIndex: 2,
          overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
          fontWeight: 700, fontSize: height * 0.34, color: ink,
          textShadow: inkShadow,
        }}
      >
        {name}
      </div>

      {/* level — centered in the cut-out window (asset x 891..1110,
          i.e. right offset 40..259) */}
      <div
        style={{
          position: "absolute", right: 40 * k, width: 219 * k, top: "18.6%", bottom: "19%",
          display: "flex", alignItems: "center", justifyContent: "center",
          zIndex: 2, fontWeight: 800, fontSize: height * 0.42, color: "#5a3315",
          textShadow: "0 1px 0 rgba(255,240,210,.5)",
        }}
      >
        {score}
      </div>
    </div>
  );
}

// -------------------------------------------------------- ParchmentButton
// Renders the approved START GAME plate art as-is (text is baked into the
// asset — public/ui/kit/start-v2.png, 1200x320, from design-ref/
// start-button-v2.png). Fixed aspect; no DOM label.
export function ParchmentButton({ onClick, style }) {
  const [down, setDown] = React.useState(false);
  return (
    <div
      role="button"
      onClick={onClick}
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      style={{
        cursor: "pointer", WebkitTapHighlightColor: "transparent",
        transform: down ? "translateY(2px) scale(.995)" : "none",
        transition: "transform .08s ease",
        filter: down ? "drop-shadow(0 2px 4px rgba(35,20,5,.4))" : "drop-shadow(0 6px 10px rgba(35,20,5,.45))",
        ...style,
      }}
    >
      <img
        src={`${KIT}start-v2.png`}
        alt="Start game"
        draggable={false}
        style={{ display: "block", width: "100%", height: "auto", userSelect: "none" }}
      />
    </div>
  );
}

// ----------------------------------------------------------------- WoodBar
export function WoodBar({ children, onClick, style, height = 40, fontSize = 16.5 }) {
  return (
    <div role="button" onClick={onClick} style={{ cursor: "pointer", WebkitTapHighlightColor: "transparent", filter: "drop-shadow(0 3px 5px rgba(30,20,10,.4))", ...style }}>
      <NineH src="close.png" assetW={1152} assetH={156} sliceL={260} sliceR={260} height={height} style={{ width: "100%" }}>
        <div
          style={{
            position: "absolute", inset: 0,
            display: "flex", alignItems: "center", justifyContent: "center",
            paddingBottom: height * 0.12,
            fontFamily: T.font, fontWeight: 700, fontSize,
            color: T.cream, textShadow: "0 1px 2px rgba(40,20,5,.7)", userSelect: "none",
          }}
        >
          {children}
        </div>
      </NineH>
    </div>
  );
}

// ---------------------------------------------------------------- PlatePill
// Approved stat plates with baked icons (public/ui/kit/pill-<kind>-v2.png):
//   gold  — iridescent glass, gold coin left      (dark ink)
//   xp    — blue-grey stone, gold diamonds left   (cream ink)
//   today — green stone, glowing orb left         (cream ink)
// The live count renders in the blank field right of the icon.
const PILLS = {
  gold:  { src: "pill-gold-v2.png",  aspect: 1217 / 549, fieldL: "40%", ink: "#474251", shadow: "0 1px 0 rgba(255,255,255,.45)" },
  xp:    { src: "pill-xp-v2.png",    aspect: 1212 / 550, fieldL: "40%", ink: "#f7e7b8", shadow: "0 1px 2px rgba(10,20,40,.7)" },
  today: { src: "pill-today-v2.png", aspect: 1218 / 490, fieldL: "36%", ink: "#eaf6e4", shadow: "0 1px 2px rgba(10,40,20,.7)" },
};

export function PlatePill({ kind, value, height = 37, style }) {
  const P = PILLS[kind] || PILLS.gold;
  return (
    <div
      style={{
        position: "relative", height, aspectRatio: String(P.aspect),
        filter: "drop-shadow(0 3px 5px rgba(20,15,8,.4))",
        ...style,
      }}
    >
      <img
        src={`${KIT}${P.src}`}
        alt=""
        draggable={false}
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%", userSelect: "none" }}
      />
      <div
        style={{
          position: "absolute", left: P.fieldL, right: "7%", top: 0, bottom: "6%",
          display: "flex", alignItems: "center", justifyContent: "center",
          fontFamily: T.font, fontWeight: 800, fontSize: height * 0.42,
          color: P.ink, textShadow: P.shadow, whiteSpace: "nowrap",
        }}
      >
        {value}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- StatPill
export function StatPill({ icon, value, style, height = 37 }) {
  return (
    <NineH src="pill.png" assetW={268} assetH={156} sliceL={60} sliceR={60} height={height} overlay={false}
           style={{ filter: "drop-shadow(0 3px 5px rgba(20,15,8,.45))", ...style }}>
      <div
        style={{
          height: "100%",
          display: "flex", alignItems: "center", justifyContent: "center", gap: 5,
          paddingBottom: height * 0.12,
          fontFamily: T.font, fontWeight: 800, fontSize: height * 0.42,
          color: T.goldText, textShadow: "0 1px 2px rgba(0,0,0,.65)", whiteSpace: "nowrap",
        }}
      >
        {icon}
        <span>{value}</span>
      </div>
    </NineH>
  );
}

export function CoinIcon({ size = 18 }) {
  return <img src={`${KIT}icon-coin.png`} alt="" style={{ width: size, height: size * (80 / 76), display: "block" }} />;
}
export function SparkIcon({ size = 18 }) {
  return <img src={`${KIT}icon-spark.png`} alt="" style={{ width: size, height: size, display: "block" }} />;
}
export function DropIcon({ size = 13 }) {
  return (
    <span style={{
      width: size, height: size, borderRadius: "50%", display: "inline-block",
      background: "radial-gradient(circle at 35% 30%, #9ff5d9, #2fae94)",
      boxShadow: "0 0 6px #4be3b8",
    }} />
  );
}

// --------------------------------------------------------------- Medallion
// Approved round stone disc (public/ui/kit/medallion-stone-v2.png). The
// carved player avatar will be layered on top once that art is ready —
// until then the disc renders blank (no initials, no placeholder).
export function Medallion({ url, avatar, name, size = 64, onClick, style }) {
  // With an avatar the component's BOX is taller than the stone: the disc sits
  // at the bottom and the character stands on it, so the whole assembly is
  // self-contained and can be positioned without clipping.
  const stoneH = size * (741 / 737);
  const boxH = stoneH; // headshot sits on the disc face — no extra headroom
  return (
    <div
      role={onClick ? "button" : undefined}
      onClick={onClick}
      style={{
        position: "relative", width: size, height: boxH,
        cursor: onClick ? "pointer" : "default",
        WebkitTapHighlightColor: "transparent",
        filter: "drop-shadow(0 4px 7px rgba(25,18,8,.45))",
        ...style,
      }}
    >
      {/* the stone only backs the FALLBACK — with a real avatar the headshot
          stands on its own */}
      {!avatar && (
        <img
          src={`${KIT}medallion-stone-v2.png`}
          alt="profile"
          draggable={false}
          style={{ position: "absolute", left: 0, bottom: 0, width: "100%", height: stoneH, userSelect: "none" }}
        />
      )}
      {avatar ? (
        <img
          src={avatar}
          alt={name || "your gardener"}
          draggable={false}
          style={{
            position: "absolute", left: "50%", top: "50%",
            height: "100%", width: "auto",
            transform: "translate(-50%,-50%)",
            pointerEvents: "none", userSelect: "none",
            filter: "drop-shadow(0 3px 5px rgba(20,14,6,.5))",
          }}
        />
      ) : url ? (
        <div style={{ position: "absolute", left: "19%", right: "19%", bottom: stoneH * 0.19, height: stoneH * 0.62, borderRadius: "50%", overflow: "hidden" }}>
          <img src={url} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        </div>
      ) : null}
    </div>
  );
}

// ------------------------------------------------------------ SquareButton
// Approved carved-wood X (public/ui/kit/x-button-v2.png, 240x242, from
// design-ref/x-button-v2.png).
export function SquareButton({ onClick, size = 48, style }) {
  return (
    <img
      src={`${KIT}x-button-v2.png`}
      alt="close"
      role="button"
      onClick={onClick}
      draggable={false}
      style={{
        width: size, height: size * (242 / 240), cursor: "pointer",
        WebkitTapHighlightColor: "transparent",
        filter: "drop-shadow(0 4px 6px rgba(25,15,5,.45))",
        ...style,
      }}
    />
  );
}

// ------------------------------------------------------------ EmberPlaque
// Ember's hunger notice: carved wood plaque with a gem meter in its groove
// (public/ui/kit/ember-hungry.png | ember-hangry.png, gems ember-gem.png /
// ember-gem-empty.png). Groove geometry measured from the plaque art, as
// fractions of the plaque box:
//   x 0.3244..0.9370   y 0.5375..0.6978
const GROOVE = { x0: 0.3244, x1: 0.937, y0: 0.5375, y1: 0.6978 };
const PLAQUE_ASPECT = 1301 / 493;

export function EmberPlaque({ pct = 100, slots = 7, width = 340, happy = false, style }) {
  const hangry = !happy && pct < 25;
  const clamped = Math.max(0, Math.min(100, pct));
  // always leave one lit gem while Ember is alive — an all-dark meter reads
  // as "broken UI" rather than "starving"
  // full belly => every gem lit (and green)
  const lit = happy ? slots : Math.max(1, Math.round((clamped / 100) * slots));
  const gw = (GROOVE.x1 - GROOVE.x0 - 0.008 * (slots - 1)) / slots;

  return (
    <div
      style={{
        position: "relative", width, aspectRatio: String(PLAQUE_ASPECT),
        filter: "drop-shadow(0 6px 12px rgba(25,15,5,.45))",
        ...style,
      }}
    >
      <img
        src={`${KIT}ember-${happy ? "happy" : hangry ? "hangry" : "hungry"}.png`}
        alt={happy ? "Ember is happy" : hangry ? "Ember is hangry" : "Ember is hungry"}
        draggable={false}
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%", userSelect: "none" }}
      />
      {Array.from({ length: slots }, (_, i) => {
        const on = i < lit;
        const last = on && i === lit - 1;
        return (
          <img
            key={i}
            src={`${KIT}ember-gem${on ? (happy ? "-green" : "") : "-empty"}.png`}
            alt=""
            draggable={false}
            style={{
              position: "absolute",
              left: `${(GROOVE.x0 + i * (gw + 0.008)) * 100}%`,
              width: `${gw * 100}%`,
              top: `${((GROOVE.y0 + GROOVE.y1) / 2) * 100}%`,
              transform: "translateY(-50%)",
              // the final lit gem breathes when Ember is hangry
              animation: last && hangry ? "emberGem 1.05s ease-in-out infinite alternate" : "none",
              filter: on
                ? happy ? "drop-shadow(0 0 4px rgba(70,220,120,.65))"
                        : "drop-shadow(0 0 3px rgba(255,140,60,.55))"
                : "none",
              transition: "opacity .25s ease",
            }}
          />
        );
      })}
      <style>{`@keyframes emberGem {
        from { filter: drop-shadow(0 0 2px rgba(255,120,50,.5)) brightness(1) }
        to   { filter: drop-shadow(0 0 9px rgba(255,150,70,.95)) brightness(1.22) }
      }`}</style>
    </div>
  );
}

// ------------------------------------------------------------- SeedPlaque
// Bottom-left seed selector: carved wood + vine plaque with a baked sprout
// icon (public/ui/kit/seed-plaque.png). Live text sits on the parchment to
// the RIGHT of the sprout — measured from the art:
//   parchment x 0.09..0.85, sprout occupies x 0.13..0.29
export function SeedPlaque({ name, count, hint, nameColor, width = 190, onClick, style }) {
  return (
    <div
      role="button"
      onClick={onClick}
      style={{
        position: "relative", width, aspectRatio: "1312 / 514",
        cursor: "pointer", WebkitTapHighlightColor: "transparent",
        filter: "drop-shadow(0 4px 8px rgba(30,25,10,.4))",
        fontFamily: T.font, userSelect: "none",
        ...style,
      }}
    >
      <img
        src={`${KIT}seed-plaque.png`}
        alt=""
        draggable={false}
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
      />
      <div
        style={{
          position: "absolute", left: "29.5%", right: "13.5%", top: "24%", bottom: "22%",
          display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
          lineHeight: 1.12, textAlign: "center",
        }}
      >
        <div style={{ fontSize: `${width * 0.074}px`, fontWeight: 800, color: nameColor || "#2f4a61", whiteSpace: "nowrap" }}>
          {name} <span style={{ color: "#c8781e" }}>×{count}</span>
        </div>
        <div style={{ fontSize: `${width * 0.057}px`, fontWeight: 600, color: "#7a6444", whiteSpace: "nowrap" }}>
          {hint}
        </div>
      </div>
    </div>
  );
}

// --------------------------------------------------------- InventorySheet
// "Home Inventory" — the blank painted board (inv-board.png) with individual
// item tiles laid on top in two rows, so every tile is its own tap target.
// Tiles are separate art with the item + name baked in
// (inv-seed-<crop>.png / inv-basket-<crop>.png).
// Geometry as fractions of the board box (measured from the art):
const BOARD_ASPECT = 976 / 884;
const TILE_W = 0.22;                       // tile width, fraction of board width
const TILE_H = TILE_W * BOARD_ASPECT / 0.952; // tiles are ~0.952 w/h
const COL_X = [0.11, 0.39, 0.67];          // three columns
const ROW_Y = { seeds: 0.305, basket: 0.615 };
// the wooden badge painted on each tile, in tile-local fractions
const BADGE = { cx: 0.825, cy: 0.155, r: 0.14 };

export function InventorySheet({ seeds = [], basket = [], width = 400, style }) {
  const tile = (cell, ci, rowKey, kind) => {
    if (!cell) return null;
    const x = COL_X[ci], y = ROW_Y[rowKey];
    return (
      <React.Fragment key={kind + ci}>
        <img
          src={`${KIT}inv-${kind}-${cell.crop}.png`}
          alt={cell.crop}
          draggable={false}
          role={cell.onClick ? "button" : undefined}
          onClick={cell.onClick}
          style={{
            position: "absolute",
            left: `${x * 100}%`, top: `${y * 100}%`,
            width: `${TILE_W * 100}%`, height: `${TILE_H * 100}%`,
            cursor: cell.onClick ? "pointer" : "default",
            WebkitTapHighlightColor: "transparent",
            filter: cell.selected
              ? "drop-shadow(0 0 7px rgba(255,201,92,.95)) drop-shadow(0 0 16px rgba(255,180,60,.7)) brightness(1.06)"
              : "drop-shadow(0 3px 5px rgba(30,20,10,.35))",
            transition: "filter .2s ease",
          }}
        />
        {/* live count on the tile's wooden badge */}
        <div
          style={{
            position: "absolute",
            left: `${(x + (BADGE.cx - BADGE.r) * TILE_W) * 100}%`,
            top: `${(y + (BADGE.cy - BADGE.r) * TILE_H) * 100}%`,
            width: `${TILE_W * BADGE.r * 2 * 100}%`,
            height: `${TILE_H * BADGE.r * 2 * 100}%`,
            display: "grid", placeItems: "center", pointerEvents: "none",
            fontFamily: T.font, fontWeight: 800, fontSize: width * 0.042,
            color: "#f6e4c0", textShadow: "0 1px 2px rgba(30,15,4,.9)",
          }}
        >
          {cell.count}
        </div>
      </React.Fragment>
    );
  };

  return (
    <div
      style={{
        position: "relative", width, aspectRatio: String(BOARD_ASPECT),
        fontFamily: T.font, userSelect: "none",
        filter: "drop-shadow(0 14px 30px rgba(25,20,10,.5))",
        ...style,
      }}
    >
      <img
        src={`${KIT}inv-board.png`}
        alt="Home inventory"
        draggable={false}
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
      />
      {seeds.slice(0, 3).map((c, i) => tile(c, i, "seeds", "seed"))}
      {basket.slice(0, 3).map((c, i) => tile(c, i, "basket", "basket"))}
    </div>
  );
}

// --------------------------------------------------------------- LevelBar
// Player levelling readout: a vertical 10-slot track that slides in from the
// left, pops the newly-earned gems into place, then slides away. Geometry
// measured from level-track.png (inner well x 0.10..0.74, y 0.041..0.989).
const TRACK_ASPECT = 191 / 1329;
const WELL = { x0: 0.10, x1: 0.74, y0: 0.041, y1: 0.989 };
const SLOTS = 10;

export function LevelBar({ level = 1, gems = 0, fx = null, height = 300, style }) {
  const [shown, setShown] = React.useState(0);   // gems currently drawn
  const [open, setOpen] = React.useState(false);
  const [levelUp, setLevelUp] = React.useState(false);
  const seen = React.useRef(null);

  React.useEffect(() => {
    if (!fx || seen.current === fx.at) return;
    seen.current = fx.at;
    setShown(fx.from);
    setOpen(true);
    // let the bar arrive, then pop the earned gems in one at a time
    const timers = [];
    timers.push(setTimeout(() => {
      for (let i = 1; i <= fx.gained; i++) {
        timers.push(setTimeout(() => setShown((v) => (v + 1 > SLOTS ? 1 : v + 1)), i * 190));
      }
    }, 420));
    const settle = 420 + fx.gained * 190 + 260;
    if (fx.levelled) timers.push(setTimeout(() => setLevelUp(true), settle));
    timers.push(setTimeout(() => { setLevelUp(false); setOpen(false); }, settle + (fx.levelled ? 1900 : 900)));
    return () => timers.forEach(clearTimeout);
  }, [fx]);

  const width = height * TRACK_ASPECT;
  const slotH = (WELL.y1 - WELL.y0) / SLOTS;

  return (
    <>
      <div
        style={{
          position: "relative", width, height,
          transform: open ? "translateX(0)" : `translateX(${-width - 26}px)`,
          opacity: open ? 1 : 0,
          transition: "transform .42s cubic-bezier(.2,1.1,.4,1), opacity .3s ease",
          pointerEvents: "none",
          filter: "drop-shadow(0 6px 14px rgba(20,30,45,.5))",
          ...style,
        }}
      >
        <img src={`${KIT}level-track.png`} alt="" draggable={false}
             style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
        {/* gems fill from the bottom up */}
        {Array.from({ length: SLOTS }, (_, i) => {
          const on = i < shown;
          const yTop = WELL.y1 - (i + 1) * slotH;
          return (
            <img
              key={i}
              src={`${KIT}level-gem.png`}
              alt=""
              draggable={false}
              style={{
                position: "absolute",
                left: `${WELL.x0 * 100}%`, width: `${(WELL.x1 - WELL.x0) * 100}%`,
                top: `${yTop * 100}%`, height: `${slotH * 100}%`,
                objectFit: "contain",
                opacity: on ? 1 : 0,
                transform: on ? "scale(1)" : "scale(.35)",
                transition: "opacity .18s ease, transform .28s cubic-bezier(.2,1.6,.4,1)",
                filter: on ? "drop-shadow(0 0 6px rgba(120,200,255,.8))" : "none",
              }}
            />
          );
        })}
        {/* current level under the track */}
        <div
          style={{
            position: "absolute", left: "50%", bottom: -height * 0.085,
            transform: "translateX(-50%)",
            fontFamily: T.font, fontWeight: 800, fontSize: height * 0.058,
            color: "#eaf6ff", textShadow: "0 2px 4px rgba(10,25,45,.85)",
            whiteSpace: "nowrap",
          }}
        >
          LV {level}
        </div>
      </div>

      {levelUp && (
        <img
          src={`${KIT}level-up-sign.png`}
          alt="Level up!"
          draggable={false}
          style={{
            position: "fixed", left: "50%", top: "34%",
            width: "min(72vw, 340px)", transform: "translate(-50%,-50%)",
            zIndex: 40, pointerEvents: "none",
            animation: "byLevelUp 1.9s ease-out both",
            filter: "drop-shadow(0 8px 18px rgba(25,15,5,.55))",
          }}
        />
      )}
      <style>{`
        @keyframes byLevelUp {
          0%   { opacity: 0; transform: translate(-50%,-50%) scale(.6) }
          18%  { opacity: 1; transform: translate(-50%,-50%) scale(1.06) }
          28%  { transform: translate(-50%,-50%) scale(1) }
          78%  { opacity: 1; transform: translate(-50%,-50%) scale(1) }
          100% { opacity: 0; transform: translate(-50%,-58%) scale(.96) }
        }
      `}</style>
    </>
  );
}

// ------------------------------------------------------------- SeedShop
// Rosie's Rare Seeds. The whole panel is painted art (rosie-member.png /
// rosie-locked.png, 760x1292) — names, tiers, prices and the padlocks are
// baked in, matching SEEDS exactly. Only the tap targets are live.
// Row geometry measured from the art, as fractions of the panel:
const SHOP_ROW_X = [0.09, 0.91];
const SHOP_ROW_Y0 = 0.2745;     // top of row 1
const SHOP_ROW_H = 0.0625;      // plank height
const SHOP_ROW_STEP = 0.0728;   // row pitch
// measured off the art: the gold plank sits BETWEEN the bottom corner stones,
// and its drop shadow runs to 0.958 — clipping short of either left a static
// sliver behind when the button pushed in
const SHOP_CLOSE = { x0: 0.105, x1: 0.878, y0: 0.888, y1: 0.958 };
const SHOP_ASPECT = 760 / 1292;

export function SeedShop({ member = false, width = 340, onBuy, onClose, style }) {
  const [pressed, setPressed] = React.useState(null);
  const [flash, setFlash] = React.useState(null);
  const [closeDown, setCloseDown] = React.useState(false);
  return (
    <div
      style={{
        position: "relative", width, aspectRatio: String(SHOP_ASPECT),
        fontFamily: T.font, userSelect: "none",
        filter: "drop-shadow(0 16px 32px rgba(25,20,10,.55))",
        ...style,
      }}
    >
      <img
        src={`${KIT}rosie-${member ? "member" : "locked"}.png`}
        alt="Rosie's Rare Seeds"
        draggable={false}
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
      />
      {Array.from({ length: 7 }, (_, i) => {
        const y = SHOP_ROW_Y0 + i * SHOP_ROW_STEP;
        const down = pressed === i;
        const bought = flash === i;
        return (
          <React.Fragment key={i}>
            {/* A second copy of the panel art, clipped to THIS plank. Because
                it sits pixel-aligned over the base image, transforming it
                makes just that plank push in — the rest stays put. */}
            <div
              style={{
                position: "absolute", inset: 0, pointerEvents: "none",
                clipPath: `inset(${y * 100}% ${(1 - SHOP_ROW_X[1]) * 100}% ${(1 - y - SHOP_ROW_H) * 100}% ${SHOP_ROW_X[0] * 100}%)`,
                transform: down ? "scale(.977) translateY(2px)" : "scale(1)",
                transformOrigin: `50% ${(y + SHOP_ROW_H / 2) * 100}%`,
                filter: down ? "brightness(.86) saturate(1.05)"
                     : bought ? "brightness(1.22) saturate(1.15)" : "none",
                transition: down ? "transform .07s ease-out, filter .07s ease-out"
                                 : "transform .22s cubic-bezier(.2,1.6,.4,1), filter .45s ease-out",
              }}
            >
              <img src={`${KIT}rosie-${member ? "member" : "locked"}.png`} alt="" draggable={false}
                   style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
            </div>
            <div
              role="button"
              onPointerDown={() => setPressed(i)}
              onPointerUp={() => setPressed(null)}
              onPointerLeave={() => setPressed(null)}
              onPointerCancel={() => setPressed(null)}
              onClick={() => {
                const ok = onBuy && onBuy(i);
                if (ok !== false) { setFlash(i); setTimeout(() => setFlash(null), 420); }
              }}
              style={{
                position: "absolute",
                left: `${SHOP_ROW_X[0] * 100}%`, width: `${(SHOP_ROW_X[1] - SHOP_ROW_X[0]) * 100}%`,
                top: `${y * 100}%`, height: `${SHOP_ROW_H * 100}%`,
                cursor: "pointer", WebkitTapHighlightColor: "transparent",
                borderRadius: "3%",
              }}
            />
          </React.Fragment>
        );
      })}
      <div
        style={{
          position: "absolute", inset: 0, pointerEvents: "none",
          clipPath: `inset(${SHOP_CLOSE.y0 * 100}% ${(1 - SHOP_CLOSE.x1) * 100}% ${(1 - SHOP_CLOSE.y1) * 100}% ${SHOP_CLOSE.x0 * 100}%)`,
          transform: closeDown ? "scale(.975) translateY(2px)" : "scale(1)",
          transformOrigin: `50% ${((SHOP_CLOSE.y0 + SHOP_CLOSE.y1) / 2) * 100}%`,
          filter: closeDown ? "brightness(.86)" : "none",
          transition: closeDown ? "transform .07s ease-out, filter .07s ease-out"
                                : "transform .22s cubic-bezier(.2,1.6,.4,1), filter .2s",
        }}
      >
        <img src={`${KIT}rosie-${member ? "member" : "locked"}.png`} alt="" draggable={false}
             style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
      </div>
      <div
        role="button"
        onPointerDown={() => setCloseDown(true)}
        onPointerUp={() => setCloseDown(false)}
        onPointerLeave={() => setCloseDown(false)}
        onClick={onClose}
        style={{
          position: "absolute",
          left: `${SHOP_CLOSE.x0 * 100}%`, width: `${(SHOP_CLOSE.x1 - SHOP_CLOSE.x0) * 100}%`,
          top: `${SHOP_CLOSE.y0 * 100}%`, height: `${(SHOP_CLOSE.y1 - SHOP_CLOSE.y0) * 100}%`,
          cursor: "pointer", WebkitTapHighlightColor: "transparent",
        }}
      />
    </div>
  );
}


// ------------------------------------------------------------- CountBadge
// A number that pops and flashes gold whenever it INCREASES — used on the
// active-item button so a purchase is visible without opening anything.
export function CountBadge({ value, style }) {
  const [pop, setPop] = React.useState(false);
  const prev = React.useRef(value);
  React.useEffect(() => {
    if (typeof value === "number" && typeof prev.current === "number" && value > prev.current) {
      setPop(true);
      const t = setTimeout(() => setPop(false), 520);
      prev.current = value;
      return () => clearTimeout(t);
    }
    prev.current = value;
  }, [value]);
  return (
    <span
      style={{
        display: "inline-block",
        transform: pop ? "scale(1.55)" : "scale(1)",
        color: pop ? "#fff3c4" : undefined,
        textShadow: pop ? "0 0 8px rgba(255,205,90,.95), 0 1px 2px rgba(30,15,4,.9)" : undefined,
        transition: pop ? "transform .16s cubic-bezier(.2,1.8,.4,1), color .12s, text-shadow .12s"
                        : "transform .34s ease, color .34s, text-shadow .34s",
        ...style,
      }}
    >
      {value}
    </span>
  );
}


// ------------------------------------------------- LockedSeedNotice
// Carved stone shown when a non-member taps a gold-priced seed. The message
// is engraved into the art; tapping anywhere dismisses it.
export function LockedSeedNotice({ onClose, width = 340, style }) {
  return (
    <div
      onClick={onClose}
      style={{
        position: "fixed", inset: 0, zIndex: 60,
        display: "flex", alignItems: "center", justifyContent: "center",
        background: "rgba(10,8,4,.45)", cursor: "pointer",
        WebkitTapHighlightColor: "transparent",
        animation: "byLockedIn .28s ease-out both",
        ...style,
      }}
    >
      <img
        src={`${KIT}locked-seed-notice.png`}
        alt="This seed requires you to be a member of a YGTeeV youth group."
        draggable={false}
        style={{
          width, maxWidth: "92vw", height: "auto", userSelect: "none",
          filter: "drop-shadow(0 18px 34px rgba(0,0,0,.6))",
          animation: "byLockedPop .34s cubic-bezier(.2,1.5,.4,1) both",
        }}
      />
      <style>{`
        @keyframes byLockedIn { from { opacity: 0 } to { opacity: 1 } }
        @keyframes byLockedPop {
          0% { transform: scale(.82) translateY(8px) }
          100% { transform: scale(1) translateY(0) }
        }
      `}</style>
    </div>
  );
}

// ------------------------------------------------------------ BerryMarket
// The painted Berry Market (market-panel.png, 720x1219). Fruit icons, names
// and the frame are baked in; quantities, prices, totals and every button are
// live overlays. Geometry measured off the art, as fractions of the panel.
const MKT_ASPECT = 754 / 1277;
const MKT_COL_X = [0.100, 0.515];          // left edge of each column
const MKT_COL_W = 0.385;
const MKT_ROW_Y = [0.208, 0.398, 0.588];   // top of each cell row
const MKT_CELL_H = 0.185;
// within a cell, as fractions of the PANEL
const MKT_BTN = { y: 0.117, h: 0.050, minus: 0.015, plus: 0.205, all: 0.285, w: 0.070, allW: 0.082 };
const MKT_BAR = { x0: 0.105, x1: 0.905, y0: 0.8207, y1: 0.8763 };
const MKT_CLOSE = { x0: 0.105, x1: 0.905, y0: 0.888, y1: 0.952 };

export function BerryMarket({ items = [], total = 0, everything = true, width = 320,
                              onBump, onAll, onSell, onClose, style }) {
  const [down, setDown] = React.useState(null);
  const press = (id) => ({
    onPointerDown: () => setDown(id),
    onPointerUp: () => setDown(null),
    onPointerLeave: () => setDown(null),
    onPointerCancel: () => setDown(null),
  });
  const pressStyle = (id) => ({
    transform: down === id ? "scale(.9) translateY(1px)" : "scale(1)",
    filter: down === id ? "brightness(.82)" : "none",
    transition: down === id ? "transform .06s ease-out, filter .06s"
                            : "transform .2s cubic-bezier(.2,1.6,.4,1), filter .2s",
  });
  const hit = (x, y, w, h, id, on, extra = {}) => (
    <div
      role="button"
      {...press(id)}
      onClick={on}
      style={{
        position: "absolute",
        left: `${x * 100}%`, top: `${y * 100}%`,
        width: `${w * 100}%`, height: `${h * 100}%`,
        cursor: "pointer", WebkitTapHighlightColor: "transparent",
        borderRadius: "18%",
        ...pressStyle(id), ...extra,
      }}
    />
  );

  return (
    <div style={{ position: "relative", width, aspectRatio: String(MKT_ASPECT), fontFamily: T.font,
                  userSelect: "none", filter: "drop-shadow(0 16px 32px rgba(25,20,10,.55))", ...style }}>
      <img src={`${KIT}market-panel.png`} alt="Berry Market" draggable={false}
           style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />

      {items.slice(0, 6).map((it, i) => {
        const cx = MKT_COL_X[i % 2], cy = MKT_ROW_Y[Math.floor(i / 2)];
        const dim = it.have <= 0;
        return (
          <React.Fragment key={it.key}>
            {/* have / unit price / line total, under the baked name */}
            <div style={{
              position: "absolute", left: `${(cx + 0.135) * 100}%`, top: `${(cy + 0.062) * 100}%`,
              width: `${(MKT_COL_W - 0.15) * 100}%`,
              fontSize: width * 0.029, fontWeight: 700, lineHeight: 1.3,
              color: dim ? "#9c8f80" : "#e9d9b8", textShadow: "0 1px 2px rgba(20,10,4,.8)",
              pointerEvents: "none",
            }}>
              have ×{it.have} · {it.unit}g ea
              <div style={{ color: dim ? "#9c8f80" : "#ffd77a", fontWeight: 800, fontSize: width * 0.036 }}>
                {it.qty * it.unit}g
              </div>
            </div>
            {/* qty, between the − and + buttons */}
            <div style={{
              position: "absolute",
              left: `${(cx + MKT_BTN.minus + MKT_BTN.w) * 100}%`,
              width: `${(MKT_BTN.plus - MKT_BTN.minus - MKT_BTN.w) * 100}%`,
              top: `${(cy + MKT_BTN.y) * 100}%`, height: `${MKT_BTN.h * 100}%`,
              display: "grid", placeItems: "center", pointerEvents: "none",
              fontSize: width * 0.042, fontWeight: 800,
              color: dim ? "#9c8f80" : "#fff6e0", textShadow: "0 1px 2px rgba(20,10,4,.85)",
            }}>{it.qty}/{it.have}</div>
            {hit(cx + MKT_BTN.minus, cy + MKT_BTN.y, MKT_BTN.w, MKT_BTN.h, `m${i}`, () => onBump && onBump(it.key, -1))}
            {hit(cx + MKT_BTN.plus,  cy + MKT_BTN.y, MKT_BTN.w, MKT_BTN.h, `p${i}`, () => onBump && onBump(it.key, +1))}
            {hit(cx + MKT_BTN.all,   cy + MKT_BTN.y, MKT_BTN.allW, MKT_BTN.h, `a${i}`, () => onAll && onAll(it.key))}
          </React.Fragment>
        );
      })}

      {/* the green sell bar — live label */}
      <div style={{
        position: "absolute", left: `${MKT_BAR.x0 * 100}%`, width: `${(MKT_BAR.x1 - MKT_BAR.x0) * 100}%`,
        top: `${MKT_BAR.y0 * 100}%`, height: `${(MKT_BAR.y1 - MKT_BAR.y0) * 100}%`,
        display: "grid", placeItems: "center", pointerEvents: "none",
        fontSize: width * 0.055, fontWeight: 800, color: "#123a12",
        textShadow: "0 1px 0 rgba(190,255,170,.55)", whiteSpace: "nowrap",
      }}>
        {total <= 0 ? "Tap + to choose fruit" : `💰 ${everything ? "Sell everything" : "Sell selected"} · +${total}g`}
      </div>
      {hit(MKT_BAR.x0, MKT_BAR.y0, MKT_BAR.x1 - MKT_BAR.x0, MKT_BAR.y1 - MKT_BAR.y0, "sell",
           () => total > 0 && onSell && onSell(), { borderRadius: "6%" })}
      {hit(MKT_CLOSE.x0, MKT_CLOSE.y0, MKT_CLOSE.x1 - MKT_CLOSE.x0, MKT_CLOSE.y1 - MKT_CLOSE.y0, "close",
           onClose, { borderRadius: "6%" })}
    </div>
  );
}

// ------------------------------------------------- CommunityInventory
// The community garden's own satchel: rare (glow) seeds ONLY — no fruit and
// nothing from the home inventory. Framed in the shared stone panel since
// there is no painted board for it.
export function CommunityInventory({ items = [], width = 330, onClose, style }) {
  const S = width / 768;
  const pad = 30 * S * 1.55;
  const tile = (width - 2 * (pad + 6) - width * 0.03) / 2;
  return (
    <div style={{ position: "relative", width, fontFamily: T.font, ...style }}>
      <StonePanel edge={38 * S * 1.55} corner={78 * S * 1.55}>
        <div style={{ padding: `${4 * S}px ${6 * S}px ${8 * S}px` }}>
          <div style={{
            textAlign: "center", fontWeight: 800, fontSize: width * 0.072,
            color: "#5a3a1e", textShadow: "0 1px 0 rgba(255,246,226,.6)", marginBottom: width * 0.018,
          }}>Community Inventory</div>
          <div style={{
            textAlign: "center", fontSize: width * 0.036, fontWeight: 700, letterSpacing: 1,
            color: "#7a4a22", marginBottom: width * 0.028,
          }}>RARE SEEDS</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: width * 0.03 }}>
            {items.map((it) => (
              <div
                key={it.crop}
                role="button"
                onClick={it.onClick}
                style={{
                  position: "relative", width: "100%", cursor: it.onClick ? "pointer" : "default",
                  WebkitTapHighlightColor: "transparent",
                  filter: it.selected
                    ? "drop-shadow(0 0 8px rgba(255,201,92,.95)) drop-shadow(0 0 18px rgba(255,180,60,.7)) brightness(1.06)"
                    : it.count > 0 ? "drop-shadow(0 3px 5px rgba(30,20,10,.35))"
                                   : "drop-shadow(0 2px 4px rgba(30,20,10,.3)) grayscale(.55) brightness(.72)",
                  transition: "filter .2s ease",
                }}
              >
                <img src={`${KIT}inv-seed-${it.crop}.png`} alt={it.crop} draggable={false}
                     style={{ width: "100%", height: "auto", display: "block" }} />
                <div style={{
                  position: "absolute", right: "6%", top: "4%", width: "27%", height: "27%",
                  display: "grid", placeItems: "center", pointerEvents: "none",
                  fontWeight: 800, fontSize: tile * 0.19,
                  color: "#f6e4c0", textShadow: "0 1px 2px rgba(30,15,4,.9)",
                }}>{it.count}</div>
              </div>
            ))}
          </div>
          {onClose && (
            <div role="button" onClick={onClose} style={{
              marginTop: width * 0.03, textAlign: "center", cursor: "pointer",
              fontSize: width * 0.042, fontWeight: 700, color: "#7a5a34",
            }}>tap to close</div>
          )}
        </div>
      </StonePanel>
    </div>
  );
}

// ---------------------------------------------------------- LevelBarH
// The same gem track as the HUD, laid on its side for the profile panel.
// Gems fill left to right.
export function LevelBarH({ gems = 0, slots = SLOTS, width = 200, style }) {
  const wellX = [WELL.y0, WELL.y1];      // the vertical track's long axis
  const wellY = [1 - WELL.x1, 1 - WELL.x0];
  const step = (wellX[1] - wellX[0]) / slots;
  return (
    <div style={{ position: "relative", width, aspectRatio: String(1329 / 191), ...style }}>
      <img src={`${KIT}level-track-h.png`} alt="" draggable={false}
           style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
      {Array.from({ length: slots }, (_, i) => (
        <img
          key={i}
          src={`${KIT}level-gem.png`}
          alt=""
          draggable={false}
          style={{
            position: "absolute",
            left: `${(wellX[0] + i * step) * 100}%`, width: `${step * 100}%`,
            top: `${wellY[0] * 100}%`, height: `${(wellY[1] - wellY[0]) * 100}%`,
            objectFit: "contain",
            opacity: i < gems ? 1 : 0,
            transform: i < gems ? "scale(1)" : "scale(.4)",
            transition: "opacity .18s ease, transform .28s cubic-bezier(.2,1.6,.4,1)",
            filter: i < gems ? "drop-shadow(0 0 5px rgba(120,200,255,.75))" : "none",
          }}
        />
      ))}
    </div>
  );
}

// -------------------------------------------------------- PlayerProfile
// The painted profile board (profile-panel.png). Header, avatar frame and the
// four buttons are art; name, level, currencies and the gem bar are live.
const PROF_ASPECT = 968 / 903;
const PROF = {
  avatar: { x: 0.125, y: 0.152, w: 0.130, h: 0.165 },   // inside the carved frame
  text:   { x: 0.300 },
  bar:    { x: 0.545, w: 0.365, y: 0.205 },
  // widths chosen so each button's rendered height (w * panelAspect / imgAspect)
  // leaves a clear gap to the next. CLOSE deliberately straddles the bottom
  // frame and HANGS OFF the board, as in the reference design.
  btns: [
    { key: "customize", top: 0.345, w: 0.62 },
    { key: "league",    top: 0.492, w: 0.62 },
    { key: "replay",    top: 0.682, w: 0.62 },
    { key: "close",     top: 0.885, w: 0.50 },
  ],
};

export function PlayerProfile({ name = "Gardener", avatar, level = 1, gems = 0,
                                gold = 0, xp = 0, width = 340, onAction, style }) {
  const [down, setDown] = React.useState(null);
  return (
    <div style={{ position: "relative", width, aspectRatio: String(PROF_ASPECT),
                  fontFamily: T.font, userSelect: "none",
                  filter: "drop-shadow(0 16px 32px rgba(25,20,10,.55))", ...style }}>
      <img src={`${KIT}profile-panel.png`} alt="Player profile" draggable={false}
           style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />

      {avatar && (
        <img src={avatar} alt="" draggable={false} style={{
          position: "absolute", left: `${PROF.avatar.x * 100}%`, top: `${PROF.avatar.y * 100}%`,
          width: `${PROF.avatar.w * 100}%`, height: `${PROF.avatar.h * 100}%`,
          objectFit: "contain", objectPosition: "center bottom", pointerEvents: "none",
        }} />
      )}

      <div style={{ position: "absolute", left: `${PROF.text.x * 100}%`, top: "15%",
                    fontWeight: 800, fontSize: width * 0.062, color: "#241a0e",
                    textShadow: "0 1px 0 rgba(255,252,242,.85)", whiteSpace: "nowrap" }}>{name}</div>
      <div style={{ position: "absolute", left: `${PROF.text.x * 100}%`, top: "22%",
                    fontWeight: 800, fontSize: width * 0.056, color: "#2e2213",
                    textShadow: "0 1px 0 rgba(255,252,242,.8)", letterSpacing: .5 }}>LEVEL {level}</div>
      <div style={{ position: "absolute", left: `${PROF.text.x * 100}%`, top: "28.5%",
                    fontWeight: 800, fontSize: width * 0.036, color: "#3a2c19",
                    textShadow: "0 1px 0 rgba(255,252,242,.75)", whiteSpace: "nowrap" }}>
        🪙 {gold} gold · ✨ {xp} gems
      </div>

      <div style={{ position: "absolute", left: `${PROF.bar.x * 100}%`, width: `${PROF.bar.w * 100}%`,
                    top: "15.5%", textAlign: "center", fontWeight: 800, fontSize: width * 0.033,
                    letterSpacing: 1, color: "#3a2c19",
                    textShadow: "0 1px 0 rgba(255,252,242,.75)" }}>LEVEL PROGRESS</div>
      <LevelBarH gems={gems} width={width * PROF.bar.w}
                 style={{ position: "absolute", left: `${PROF.bar.x * 100}%`, top: `${PROF.bar.y * 100}%` }} />

      {PROF.btns.map((b) => (
        <img
          key={b.key}
          src={`${KIT}btn-${b.key}.png`}
          alt={b.key}
          draggable={false}
          role="button"
          onPointerDown={() => setDown(b.key)}
          onPointerUp={() => setDown(null)}
          onPointerLeave={() => setDown(null)}
          onClick={() => onAction && onAction(b.key)}
          style={{
            position: "absolute", left: `${((1 - b.w) / 2) * 100}%`, top: `${b.top * 100}%`,
            width: `${b.w * 100}%`, height: "auto", cursor: "pointer",
            WebkitTapHighlightColor: "transparent",
            transform: down === b.key ? "scale(.972) translateY(2px)" : "scale(1)",
            filter: down === b.key ? "brightness(.88)" : "none",
            transition: down === b.key ? "transform .07s ease-out, filter .07s"
                                       : "transform .22s cubic-bezier(.2,1.6,.4,1), filter .2s",
          }}
        />
      ))}
    </div>
  );
}

// -------------------------------------------------------------- Wardrobe
// Character customisation in the carved-stone/warm-wood language: a
// StonePanel board, a wood title plank, carved section labels, stone-rimmed
// colour studs and wood chips for hats/accessories. CLOSE hangs off the
// bottom frame exactly like the Player Profile board.
// stud diameter as a fraction of panel width — sized so six studs fit one row
const STUD = 0.107;

// outfit colours arrive as three.js hex ints (0xf7d7b6); CSS needs a string
const cssColor = (c) => (typeof c === "number" ? "#" + c.toString(16).padStart(6, "0") : c);

function Stud({ color, sel, size, onPick }) {
  const [down, setDown] = React.useState(false);
  const hex = cssColor(color);
  return (
    <div
      role="button"
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      onClick={onPick}
      style={{
        width: size, height: size, boxSizing: "border-box", borderRadius: "50%", cursor: "pointer",
        WebkitTapHighlightColor: "transparent", flex: "0 0 auto",
        background: `radial-gradient(circle at 34% 28%, ${hex}, ${hex} 58%, rgba(0,0,0,.30))`,
        // carved stone rim; the selected stud gets a warm gold collar
        border: `${Math.max(2, size * 0.09)}px solid ${sel ? "#f0c261" : "#8d8073"}`,
        boxShadow: sel
          ? `0 0 0 ${size * 0.05}px rgba(90,72,44,.55), 0 0 ${size * 0.34}px rgba(247,199,102,.75), inset 0 ${size * 0.09}px ${size * 0.14}px rgba(255,255,255,.3), inset 0 -${size * 0.1}px ${size * 0.14}px rgba(0,0,0,.34)`
          : `0 2px 4px rgba(35,25,12,.45), inset 0 ${size * 0.09}px ${size * 0.14}px rgba(255,255,255,.26), inset 0 -${size * 0.1}px ${size * 0.14}px rgba(0,0,0,.34)`,
        transform: down ? "scale(.9)" : sel ? "scale(1.06)" : "scale(1)",
        transition: down ? "transform .07s ease-out" : "transform .2s cubic-bezier(.2,1.6,.4,1), box-shadow .2s",
      }}
    />
  );
}

function WoodChip({ emoji, label, sel, w, onPick }) {
  const [down, setDown] = React.useState(false);
  return (
    <div
      role="button"
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      onClick={onPick}
      style={{
        width: w, boxSizing: "border-box", cursor: "pointer", flex: "0 0 auto",
        WebkitTapHighlightColor: "transparent",
        display: "flex", flexDirection: "column", alignItems: "center", gap: w * 0.03,
        padding: `${w * 0.09}px ${w * 0.05}px ${w * 0.08}px`,
        borderRadius: w * 0.14,
        // planked wood face, darker grain at the foot
        background: sel
          ? "linear-gradient(180deg, #a8794a, #7d5330 62%, #63401f)"
          : "linear-gradient(180deg, #8a6440, #6b4626 62%, #533618)",
        border: `${Math.max(2, w * 0.028)}px solid ${sel ? "#f0c261" : "#4a2f16"}`,
        boxShadow: sel
          ? `0 0 ${w * 0.16}px rgba(247,199,102,.6), inset 0 2px 0 rgba(255,226,180,.35), 0 3px 5px rgba(30,20,10,.45)`
          : "inset 0 2px 0 rgba(255,226,180,.2), 0 3px 5px rgba(30,20,10,.45)",
        transform: down ? "scale(.94) translateY(2px)" : "scale(1)",
        transition: down ? "transform .07s ease-out" : "transform .2s cubic-bezier(.2,1.6,.4,1), box-shadow .2s",
      }}
    >
      <span style={{ fontSize: w * 0.34, lineHeight: 1, filter: "drop-shadow(0 1px 2px rgba(20,12,4,.55))" }}>{emoji}</span>
      <span style={{
        fontFamily: T.font, fontWeight: 700, fontSize: w * 0.145,
        color: sel ? "#ffe9b8" : T.idleText, textShadow: "0 1px 2px rgba(35,18,4,.75)",
        whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", maxWidth: "100%",
      }}>{label}</span>
    </div>
  );
}

export function Wardrobe({ groups = [], outfit = {}, onPick, onRandom, onClose,
                           width = 330, style }) {
  const [cat, setCat] = React.useState(groups[0]?.key);
  const [closeDown, setCloseDown] = React.useState(false);
  const active = groups.find((g) => g.key === cat) || groups[0];
  const edge = width * 0.086;
  const studSize = width * 0.100; // six fit one row inside the frame
  const chipW = width * 0.155;
  // two rows of options, fixed — so the sheet never changes height between
  // categories and the character behind it never shifts
  const rowH = active?.type === "chip" ? chipW * 1.06 : studSize;
  // Every category fits in two rows, so this area never needs to scroll.
  // It is deliberately NOT a scroll container: an overflow box whose top
  // edge sits flush on the studs clips their rim, selection ring and glow.
  const pad = rowH * 0.16;
  const optH = rowH * 2 + rowH * 0.26 + pad * 2;

  return (
    <div style={{ position: "relative", width, fontFamily: T.font, userSelect: "none",
                  paddingBottom: width * 0.10, ...style }}>
      <StonePanel edge={edge} corner={edge * 2.05}>
        <WoodBar height={width * 0.118} fontSize={width * 0.055}
                 style={{ margin: `0 ${width * 0.08}px ${width * 0.035}px`, cursor: "default" }}>
          WARDROBE
        </WoodBar>

        {/* category picker — carved tabs, one row */}
        <div style={{ display: "flex", gap: width * 0.016, justifyContent: "center",
                      flexWrap: "wrap", marginBottom: width * 0.032 }}>
          {groups.map((g) => (
            <CatTab key={g.key} label={g.label} sel={g.key === cat}
                    h={width * 0.082} onPick={() => setCat(g.key)} />
          ))}
        </div>

        {/* options for the active category */}
        <div style={{ minHeight: optH, boxSizing: "border-box", padding: `${pad}px 0`,
                      display: "flex", flexWrap: "wrap", justifyContent: "center",
                      alignContent: "flex-start",
                      gap: active?.type === "chip" ? chipW * 0.11 : studSize * 0.26 }}>
          {active?.type === "chip"
            ? active.list.map((o) => (
                <WoodChip key={o.k} emoji={o.e} label={o.n} w={chipW}
                          sel={outfit[active.key] === o.k}
                          onPick={() => onPick && onPick(active.key, o.k)} />
              ))
            : (active?.list || []).map((c) => (
                <Stud key={String(c)} color={c} size={studSize}
                      sel={outfit[active.key] === c}
                      onPick={() => onPick && onPick(active.key, c)} />
              ))}
        </div>

        <WoodBar onClick={onRandom} height={width * 0.108} fontSize={width * 0.047}
                 style={{ margin: `${width * 0.035}px ${width * 0.12}px ${width * 0.05}px` }}>
          🎲 Surprise me
        </WoodBar>
      </StonePanel>

      {/* CLOSE straddles the bottom frame and hangs off the board */}
      <img
        src={`${KIT}btn-close.png`} alt="Close" draggable={false} role="button"
        onPointerDown={() => setCloseDown(true)}
        onPointerUp={() => setCloseDown(false)}
        onPointerLeave={() => setCloseDown(false)}
        onClick={onClose}
        style={{
          position: "absolute", left: "50%", bottom: 0, width: width * 0.46,
          transform: `translateX(-50%) ${closeDown ? "scale(.972) translateY(2px)" : ""}`,
          cursor: "pointer", WebkitTapHighlightColor: "transparent", zIndex: 4,
          filter: closeDown ? "brightness(.88)" : "none",
          transition: closeDown ? "transform .07s ease-out, filter .07s"
                                : "transform .22s cubic-bezier(.2,1.6,.4,1), filter .2s",
        }}
      />
    </div>
  );
}

function CatTab({ label, sel, h, onPick }) {
  const [down, setDown] = React.useState(false);
  return (
    <div
      role="button"
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      onClick={onPick}
      style={{
        height: h, display: "flex", alignItems: "center", padding: `0 ${h * 0.46}px`,
        borderRadius: h * 0.30, cursor: "pointer", WebkitTapHighlightColor: "transparent",
        fontFamily: T.font, fontWeight: 800, fontSize: h * 0.44, letterSpacing: .6,
        background: sel
          ? "linear-gradient(180deg, #a8794a, #7d5330 62%, #63401f)"
          : "linear-gradient(180deg, #b6ab99, #968a78 62%, #7b7060)",
        border: `${Math.max(1.5, h * 0.055)}px solid ${sel ? "#f0c261" : "#6a6154"}`,
        color: sel ? "#ffe9b8" : "#f2ece0",
        textShadow: "0 1px 2px rgba(35,22,8,.7)",
        boxShadow: sel
          ? `0 0 ${h * 0.4}px rgba(247,199,102,.55), inset 0 2px 0 rgba(255,226,180,.3), 0 2px 4px rgba(30,20,10,.4)`
          : "inset 0 2px 0 rgba(255,255,255,.22), 0 2px 4px rgba(30,20,10,.4)",
        transform: down ? "scale(.94)" : "scale(1)",
        transition: down ? "transform .07s ease-out" : "transform .2s cubic-bezier(.2,1.6,.4,1), box-shadow .2s",
      }}
    >{label}</div>
  );
}
