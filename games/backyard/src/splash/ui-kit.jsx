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

// Gate a painted board on its art being loaded — otherwise the live DOM
// layer (pills, counts, labels) pops in a beat before the image and the
// menu looks broken for a flash. Resolves instantly for cached art.
function useArtReady(...srcs) {
  const [n, setN] = React.useState(0);
  React.useEffect(() => {
    let dead = false;
    let done = 0;
    srcs.forEach((src) => {
      const im = new Image();
      im.onload = im.onerror = () => { if (!dead) { done++; setN(done); } };
      im.src = src;
    });
    return () => { dead = true; };
  }, [srcs.join("|")]); // eslint-disable-line react-hooks/exhaustive-deps
  return n >= srcs.length;
}

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
// The labels used to be baked into tab-{key}-v2.png, which fixed both the
// wording and the width. "Garden League" is twice the length of "Groups", so
// the slab is now a 3-slice blank (tab-blank-v2.png, cut from the approved
// Groups art) with the label as live text — any wording, any width, same
// painted stone. `weight` flexes a tab wider for a longer label.
export function TabToggle({ tabs, active, onChange, height = 56, fontSize = 20, style }) {
  return (
    <div style={{ display: "flex", gap: 14, alignItems: "stretch", ...style }}>
      {tabs.map((t) => {
        const on = t.key === active;
        return (
          <div
            key={t.key}
            role="button"
            onClick={() => onChange && onChange(t.key)}
            style={{
              flex: `${t.weight || 1} 1 0`, minWidth: 0,
              cursor: "pointer", WebkitTapHighlightColor: "transparent", userSelect: "none",
              filter: on
                ? "drop-shadow(0 0 6px #7ef0a0) drop-shadow(0 0 14px #57d97fcc) brightness(1.06)"
                : "drop-shadow(0 3px 4px rgba(30,25,15,.35)) brightness(.94) saturate(.92)",
              transition: "filter .22s ease",
            }}
          >
            <NineH
              src="tab-blank-v2.png" assetW={292} assetH={188}
              sliceL={140} sliceR={140} height={height} style={{ width: "100%" }}
            >
              <div
                style={{
                  position: "absolute", inset: 0,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  padding: `0 ${height * 0.12}px ${height * 0.08}px`,
                  fontFamily: T.font, fontWeight: 700, fontSize,
                  color: "#ede9c5", textShadow: "0 2px 3px rgba(28,24,16,.6)",
                  whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                }}
              >
                {t.label}
              </div>
            </NineH>
          </div>
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
  // The cut-out window fits about 3 glyphs at full size; berry totals run to
  // five figures, so step the score down rather than let it slide under the
  // painted edge.
  const digits = String(score ?? "").length;
  const scoreScale = digits <= 3 ? 0.42 : digits === 4 ? 0.35 : digits === 5 ? 0.29 : 0.25;
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
          zIndex: 2, fontWeight: 800, fontSize: height * scoreScale, color: "#5a3315",
          textShadow: "0 1px 0 rgba(255,240,210,.5)",
          overflow: "hidden", whiteSpace: "nowrap",
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
  // community-garden berry counter — carved jade, no baked icon, so the
  // value centres across the whole plate
  berries: { src: "pill-berries.png", aspect: 1218 / 490, fieldL: "7%", ink: "#f2fff0", shadow: "0 1px 3px rgba(8,32,12,.85)" },
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
  // full belly => every gem lit (and green); an EMPTY meter is deliberate —
  // it's the "he's about to charge" beat right before the rampage
  const lit = happy ? slots : Math.round((clamped / 100) * slots);
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

// onLevelReady/badgeAt let a parent slip something in between the bar
// filling and the LEVEL UP badge — the reading mini player does exactly
// that. Without them the bar behaves as it always has.
export function LevelBar({ level = 1, gems = 0, fx = null, height = 300, onLevelReady, badgeAt = null, style }) {
  const [shown, setShown] = React.useState(0);   // gems currently drawn
  const [open, setOpen] = React.useState(false);
  const [levelUp, setLevelUp] = React.useState(false);
  const seen = React.useRef(null);
  const owed = React.useRef(false);
  const ready = React.useRef(null);
  ready.current = onLevelReady;

  React.useEffect(() => {
    if (!fx || seen.current === fx.at) return;
    seen.current = fx.at;
    // Harvesting a second plot inside the ~1.4s animation window replaces fx
    // and tears this effect down, cancelling its timers. A level-up owed by
    // an earlier award has to survive that hand-off or it is swallowed
    // silently — no badge, no reading offer. The flag carries it forward to
    // whichever run actually gets to finish.
    if (fx.levelled) owed.current = true;
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
    timers.push(setTimeout(() => {
      if (!owed.current) {
        timers.push(setTimeout(() => setOpen(false), 900));
        return;
      }
      owed.current = false;
      if (ready.current) {
        // parent owns the badge from here — hand off and clear the track
        ready.current();
        timers.push(setTimeout(() => setOpen(false), 520));
      } else {
        setLevelUp(true);
        timers.push(setTimeout(() => { setLevelUp(false); setOpen(false); }, 1900));
      }
    }, settle));
    return () => timers.forEach(clearTimeout);
  }, [fx]);

  // parent-fired badge (after the reading offer resolves)
  React.useEffect(() => {
    if (!badgeAt) return;
    setLevelUp(true);
    const t = setTimeout(() => { setLevelUp(false); setOpen(false); }, 1900);
    return () => clearTimeout(t);
  }, [badgeAt]);

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
const SHOP_ROW_X = [0.10, 0.91];
// measured on rosie-rare-v3.png (756x1346): 7 plank centres, even ~0.0742 pitch
const SHOP_ROW_C = [0.298, 0.376, 0.449, 0.523, 0.597, 0.672, 0.747];
const SHOP_ROW_H = 0.071;
// measured off the art: the gold plank sits BETWEEN the bottom corner stones,
// and its drop shadow runs to 0.958 — clipping short of either left a static
// sliver behind when the button pushed in
const SHOP_CLOSE = { x0: 0.147, x1: 0.837, y0: 0.862, y1: 0.914 };
const SHOP_ASPECT = 756 / 1346;

export function SeedShop({ member = false, width = 340, rows = [], onBuy, onExplain, onClose, style }) {
  const [hold, setHold] = React.useState(null); // { i, pct }
  const [closeDown, setCloseDown] = React.useState(false);
  const timer = React.useRef(null);
  const stopHold = () => { if (timer.current) clearInterval(timer.current); timer.current = null; setHold(null); };
  React.useEffect(() => stopHold, []);
  const startHold = (i2) => {
    stopHold();
    const t0 = performance.now();
    timer.current = setInterval(() => {
      const pct = Math.min(1, (performance.now() - t0) / 750);
      setHold({ i: i2, pct });
      if (pct >= 1) { stopHold(); onBuy && onBuy(i2); }
    }, 33);
  };
  const ART = `${KIT}rosie-rare-v3.png`;
  const ready = useArtReady(ART);
  const pillH = width * 0.088;
  return (
    <div
      style={{
        position: "relative", width, aspectRatio: String(SHOP_ASPECT),
        fontFamily: T.font, userSelect: "none",
        filter: "drop-shadow(0 16px 32px rgba(25,20,10,.55))",
        opacity: ready ? 1 : 0, transition: "opacity .18s ease",
        ...style,
      }}
    >
      <img src={ART} alt="Rosie's Rare Seeds" draggable={false}
           style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
      {SHOP_ROW_C.map((c, i2) => {
        const r = rows[i2] || {};
        if (r.cost == null) return null;
        const lockedRow = !member && r.kind === "gold";
        const holding = hold && hold.i === i2;
        // the wallet pill IS the buy button: hold it and it fills gold
        return (
          <div
            key={i2}
            role="button"
            onPointerDown={(e) => {
              e.stopPropagation();
              if (lockedRow) { onExplain && onExplain(i2, "locked"); return; }
              if (!r.afford) { onExplain && onExplain(i2, "poor"); return; }
              startHold(i2);
            }}
            onPointerUp={stopHold}
            onPointerLeave={stopHold}
            onPointerCancel={stopHold}
            style={{
              position: "absolute", right: "9.5%", top: `${c * 100}%`,
              transform: `translateY(-50%) ${holding ? "scale(1.06)" : "scale(1)"}`,
              cursor: "pointer", WebkitTapHighlightColor: "transparent",
              opacity: lockedRow ? 0.55 : r.afford ? 1 : 0.72,
              filter: lockedRow ? "grayscale(.45)" : "none",
              transition: holding ? "transform .1s ease-out" : "transform .22s cubic-bezier(.2,1.6,.4,1)",
            }}
          >
            <div style={{ position: "relative", overflow: "hidden", borderRadius: pillH * 0.5 }}>
              <PlatePill kind={r.kind === "gold" ? "gold" : "xp"} value={r.cost} height={pillH} />
              {holding && (
                <div style={{
                  position: "absolute", left: 0, top: 0, bottom: 0, width: `${hold.pct * 100}%`,
                  background: "rgba(255,214,120,.5)", pointerEvents: "none",
                  boxShadow: "0 0 12px rgba(255,199,102,.8)",
                }} />
              )}
            </div>
            {lockedRow && (
              <span style={{ position: "absolute", right: -6, top: -9, fontSize: width * 0.045,
                             filter: "drop-shadow(0 1px 2px rgba(20,12,4,.6))" }}>🔒</span>
            )}
          </div>
        );
      })}
      {/* CLOSE plank */}
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
      {closeDown && (
        <div style={{
          position: "absolute", inset: 0, pointerEvents: "none",
          clipPath: `inset(${SHOP_CLOSE.y0 * 100}% ${(1 - SHOP_CLOSE.x1) * 100}% ${(1 - SHOP_CLOSE.y1) * 100}% ${SHOP_CLOSE.x0 * 100}%)`,
          transform: "scale(.98) translateY(2px)",
          transformOrigin: `50% ${((SHOP_CLOSE.y0 + SHOP_CLOSE.y1) / 2) * 100}%`,
          filter: "brightness(.85)",
        }}>
          <img src={ART} alt="" draggable={false}
               style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
        </div>
      )}
    </div>
  );
}

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
// three-row painted board (market-v2.png) + the green crystal sell bar
// (market-sell-bar.png). Live layer: inventory counts in the stone tabs,
// qty between - and +, per-row line totals with the standard coin, and the
// sell bar's label. Rows/geometry measured on the art.
const MKT2 = {
  btnY: [0.3357, 0.5333, 0.7357],   // -/+/ALL row centres
  minusX: 0.3386, plusX: 0.6507, allX: 0.7795, qtyX: 0.498,
  btnW: 0.085, btnH: 0.052, allW: 0.115,
  invY: [0.2612, 0.4635, 0.6650], invX: 0.862, // beside the "Inv:" label inside the tab
  totY: [0.3812, 0.5788, 0.7812],
  bar: { x0: 0.0996, x1: 0.8964, y0: 0.818, y1: 0.8847 },
  close: { x0: 0.1262, x1: 0.8632, y0: 0.8965, y1: 0.9569 },
  aspect: 753 / 1275,
};

export function BerryMarket({ items = [], total = 0, everything = true, width = 320,
                              onBump, onAll, onSell, onClose, style }) {
  const [down, setDown] = React.useState(null);
  const [sellHold, setSellHold] = React.useState(0); // 0..1 fill while holding
  const sellTimer = React.useRef(null);
  const stopSellHold = () => { if (sellTimer.current) clearInterval(sellTimer.current); sellTimer.current = null; setSellHold(0); };
  React.useEffect(() => stopSellHold, []);
  const startSellHold = () => {
    stopSellHold();
    const t0 = performance.now();
    sellTimer.current = setInterval(() => {
      const pct = Math.min(1, (performance.now() - t0) / 750);
      setSellHold(pct);
      if (pct >= 1) { stopSellHold(); onSell && onSell(); }
    }, 33);
  };
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
  const hit = (cx, cy, w, h, id, on, extra = {}) => (
    <div
      role="button"
      {...press(id)}
      onClick={on}
      style={{
        position: "absolute",
        left: `${(cx - w / 2) * 100}%`, top: `${(cy - h / 2) * 100}%`,
        width: `${w * 100}%`, height: `${h * 100}%`,
        cursor: "pointer", WebkitTapHighlightColor: "transparent",
        borderRadius: "18%",
        ...pressStyle(id), ...extra,
      }}
    />
  );

  const ready = useArtReady(`${KIT}market-v2.png`, `${KIT}market-sell-bar.png`);
  return (
    <div style={{ position: "relative", width, aspectRatio: String(MKT2.aspect), fontFamily: T.font,
                  userSelect: "none", filter: "drop-shadow(0 16px 32px rgba(25,20,10,.55))",
                  opacity: ready ? 1 : 0, transition: "opacity .18s ease", ...style }}>
      <img src={`${KIT}market-v2.png`} alt="Berry Market" draggable={false}
           style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />

      {items.slice(0, 3).map((it, i2) => {
        const dim = it.have <= 0;
        return (
          <React.Fragment key={it.key}>
            {/* live inventory count in the stone tab */}
            <div style={{
              position: "absolute", left: `${(MKT2.invX - 0.07) * 100}%`, width: "14%",
              top: `${MKT2.invY[i2] * 100}%`, transform: "translateY(-50%)",
              textAlign: "center", pointerEvents: "none",
              fontSize: width * 0.044, fontWeight: 800,
              color: dim ? "#9c8f80" : "#fff6e0", textShadow: "0 1px 2px rgba(20,10,4,.85)",
            }}>{it.have}</div>
            {/* qty selected, between - and + */}
            <div style={{
              position: "absolute", left: `${(MKT2.qtyX - 0.12) * 100}%`, width: "24%",
              top: `${MKT2.btnY[i2] * 100}%`, transform: "translateY(-50%)",
              textAlign: "center", pointerEvents: "none",
              fontSize: width * 0.05, fontWeight: 800,
              color: dim ? "#9c8f80" : "#fff6e0", textShadow: "0 1px 2px rgba(20,10,4,.85)",
            }}>{it.qty}</div>
            {/* line total on the little plank, standard coin */}
            <div style={{
              position: "absolute", left: `${(MKT2.qtyX - 0.12) * 100}%`, width: "24%",
              top: `${MKT2.totY[i2] * 100}%`, transform: "translateY(-50%)",
              display: "flex", alignItems: "center", justifyContent: "center", gap: width * 0.012,
              pointerEvents: "none", opacity: it.qty > 0 ? 1 : 0.5,
            }}>
              <CoinIcon size={width * 0.038} />
              <b style={{ fontSize: width * 0.036, color: "#ffd77a", textShadow: "0 1px 2px rgba(20,10,4,.85)" }}>{it.qty * it.unit}</b>
            </div>
            {hit(MKT2.minusX, MKT2.btnY[i2], MKT2.btnW, MKT2.btnH, `m${i2}`, () => onBump && onBump(it.key, -1))}
            {hit(MKT2.plusX,  MKT2.btnY[i2], MKT2.btnW, MKT2.btnH, `p${i2}`, () => onBump && onBump(it.key, +1))}
            {hit(MKT2.allX,   MKT2.btnY[i2], MKT2.allW, MKT2.btnH, `a${i2}`, () => onAll && onAll(it.key))}
          </React.Fragment>
        );
      })}

      {/* the green crystal sell bar — HOLD to confirm, gold fill sweep */}
      <div
        role="button"
        onPointerDown={() => { if (total > 0) startSellHold(); }}
        onPointerUp={stopSellHold}
        onPointerLeave={stopSellHold}
        onPointerCancel={stopSellHold}
        style={{
          position: "absolute",
          left: `${MKT2.bar.x0 * 100}%`, width: `${(MKT2.bar.x1 - MKT2.bar.x0) * 100}%`,
          top: `${MKT2.bar.y0 * 100}%`, height: `${(MKT2.bar.y1 - MKT2.bar.y0) * 100}%`,
          cursor: total > 0 ? "pointer" : "default", WebkitTapHighlightColor: "transparent",
          opacity: total > 0 ? 1 : 0.6, filter: total > 0 ? "none" : "grayscale(.35)",
          transform: sellHold > 0 ? "scale(1.03)" : "scale(1)",
          transition: "transform .12s ease-out",
        }}
      >
        <img src={`${KIT}market-sell-bar.png`} alt="" draggable={false}
             style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
        {sellHold > 0 && (
          <div style={{
            position: "absolute", inset: 0,
            clipPath: "polygon(4% 0, 96% 0, 100% 50%, 96% 100%, 4% 100%, 0 50%)",
            pointerEvents: "none",
          }}>
            <div style={{
              position: "absolute", left: 0, top: 0, bottom: 0, width: `${sellHold * 100}%`,
              background: "rgba(255,214,120,.55)",
              boxShadow: "0 0 14px rgba(255,199,102,.9)",
            }} />
          </div>
        )}
        <div style={{
          position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center",
          gap: width * 0.014, pointerEvents: "none",
          fontSize: width * 0.046, fontWeight: 800, color: "#fff6e0",
          textShadow: "0 2px 3px rgba(8,40,12,.95), 0 0 10px rgba(8,40,12,.6)",
          whiteSpace: "nowrap", padding: "0 8%", boxSizing: "border-box",
        }}>
          {total <= 0 ? (
            "Tap + to sell fruit"
          ) : (
            <>
              <span>Hold to sell · +{total}</span>
              <CoinIcon size={width * 0.05} />
            </>
          )}
        </div>
      </div>

      {hit((MKT2.close.x0 + MKT2.close.x1) / 2, (MKT2.close.y0 + MKT2.close.y1) / 2,
           MKT2.close.x1 - MKT2.close.x0, MKT2.close.y1 - MKT2.close.y0, "close", onClose, { borderRadius: "6%" })}
    </div>
  );
}

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
  // measured off the carved frame's OPENING in profile-panel.png. The old
  // box hung ~2.7% below it, which is what sat the portrait low in the stone.
  avatar: { x: 0.134, y: 0.146, w: 0.121, h: 0.146 },
  text:   { x: 0.300 },
  // widths chosen so each button's rendered height (w * panelAspect / imgAspect)
  // leaves a clear gap to the next. CLOSE deliberately straddles the bottom
  // frame and HANGS OFF the board, as in the reference design.
  // `label` marks a button that renders on the shared black slab
  // (slab-black-blank.png) with live lettering, rather than as baked art.
  // Both slabs are the same height, so the tops are spaced evenly.
  btns: [
    { key: "customize", top: 0.345, w: 0.62, label: "CUSTOMIZE CHARACTER", locked: true },
    { key: "league",    top: 0.506, w: 0.62, label: "WEEKLY LEADERBOARD" },
    { key: "replay",    top: 0.682, w: 0.62 },
    { key: "close",     top: 0.885, w: 0.50 },
  ],
};

// The slab lettering is a condensed grotesque, matching the carved signs.
// Baloo (the kit's display face) is far too wide to fit nineteen characters
// across a button this size.
const SLAB_FONT = `"Arial Narrow", "Roboto Condensed", "Oswald", "Haettenschweiler", sans-serif`;
const SLAB_ASPECT = 1000 / 226;

function Padlock({ size = 12 }) {
  return (
    <svg width={size} height={size * 1.16} viewBox="0 0 20 23" aria-hidden="true"
         style={{ display: "block", flex: "0 0 auto", filter: "drop-shadow(0 1px 1px rgba(0,0,0,.6))" }}>
      <path d="M6 9V6.5a4 4 0 0 1 8 0V9" fill="none" stroke="#d9d3c4" strokeWidth="2.6" strokeLinecap="round" />
      <rect x="2.5" y="9" width="15" height="12" rx="2.6" fill="#d9d3c4" />
      <circle cx="10" cy="14.4" r="1.9" fill="#5a5347" />
      <rect x="9.1" y="14.4" width="1.8" height="3.6" rx=".9" fill="#5a5347" />
    </svg>
  );
}

export function PlayerProfile({ name = "Gardener", avatar, level = 1,
                                gold = 0, xp = 0, width = 340, onAction, onInfo, style }) {
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
          // centred in the carved frame — "bottom" sat the portrait low in
          // the stone, leaving a gap above the hat
          objectFit: "contain", objectPosition: "center", pointerEvents: "none",
        }} />
      )}

      {/* Name + level, centred against the avatar frame. The gem track that
          used to sit above them moved to the main HUD, so this block now
          owns the whole space beside the portrait. */}
      <div style={{
        position: "absolute", left: `${PROF.text.x * 100}%`,
        top: `${((PROF.avatar.y + PROF.avatar.h / 2) * 100).toFixed(2)}%`,
        transform: "translateY(-50%)", whiteSpace: "nowrap",
        display: "flex", flexDirection: "column", gap: width * 0.006,
        color: "#ffffff", textShadow: "0 2px 4px rgba(28,20,10,.8), 0 0 8px rgba(28,20,10,.4)",
      }}>
        <div style={{
          fontWeight: 800, fontSize: width * 0.068, lineHeight: 1.05,
          maxWidth: width * 0.46, overflow: "hidden", textOverflow: "ellipsis",
        }}>{name}</div>
        <div style={{ fontWeight: 800, fontSize: width * 0.056, letterSpacing: .5, lineHeight: 1.05 }}>
          LEVEL {level}
        </div>
      </div>

      {/* carved info stud — opens the Gardener's Almanac */}
      {onInfo && (
        <div
          role="button"
          onClick={onInfo}
          style={{
            // clear of the painted frame: the top-right corner stone reaches
            // down to ~13% and the right rail's inner edge is at ~92.5%
            position: "absolute", right: "9.5%", top: "14.5%", width: "10.5%", aspectRatio: "1",
            borderRadius: "50%", cursor: "pointer", WebkitTapHighlightColor: "transparent",
            display: "flex", alignItems: "center", justifyContent: "center",
            background: "linear-gradient(180deg, #a8794a, #7d5330 62%, #63401f)",
            border: `${Math.max(2, width * 0.008)}px solid #4a2f16`,
            boxShadow: "inset 0 2px 0 rgba(255,226,180,.3), 0 2px 5px rgba(30,20,10,.5)",
            color: "#ffe9b8", fontFamily: "Georgia, serif", fontStyle: "italic",
            fontWeight: 700, fontSize: width * 0.062, textShadow: "0 1px 2px rgba(35,18,4,.8)",
            userSelect: "none",
          }}
        >i</div>
      )}
      {PROF.btns.map((b) => {
        const press = {
          transform: down === b.key ? "scale(.972) translateY(2px)" : "scale(1)",
          filter: down === b.key ? "brightness(.88)" : "none",
          transition: down === b.key ? "transform .07s ease-out, filter .07s"
                                     : "transform .22s cubic-bezier(.2,1.6,.4,1), filter .2s",
        };
        const hit = {
          onPointerDown: () => setDown(b.key),
          onPointerUp: () => setDown(null),
          onPointerLeave: () => setDown(null),
          onClick: () => onAction && onAction(b.key),
        };
        const place = {
          position: "absolute", left: `${((1 - b.w) / 2) * 100}%`, top: `${b.top * 100}%`,
          width: `${b.w * 100}%`, cursor: "pointer", WebkitTapHighlightColor: "transparent",
        };
        if (b.label) {
          const bw = width * b.w;
          return (
            <div key={b.key} role="button" {...hit}
                 style={{ ...place, aspectRatio: String(SLAB_ASPECT), ...press }}>
              <img src={`${KIT}slab-black-blank.png`} alt="" draggable={false}
                   style={{ position: "absolute", inset: 0, width: "100%", height: "100%",
                            filter: b.locked ? "grayscale(.5) brightness(.72)" : "none" }} />
              <div style={{
                position: "absolute", inset: 0, display: "flex",
                alignItems: "center", justifyContent: "center", gap: bw * 0.022,
                paddingBottom: bw * 0.012,
                fontFamily: SLAB_FONT, fontWeight: 700, fontSize: bw * 0.077,
                letterSpacing: bw * 0.004, whiteSpace: "nowrap",
                color: b.locked ? "#b9b3a6" : "#f4f2ec",
                textShadow: "0 1px 0 rgba(255,255,255,.18), 0 2px 3px rgba(0,0,0,.8)",
              }}>
                {b.locked && <Padlock size={bw * 0.072} />}
                {b.label}
              </div>
              {b.locked && (
                <div style={{
                  position: "absolute", left: 0, right: 0, bottom: bw * 0.012,
                  textAlign: "center", fontFamily: T.font, fontWeight: 800,
                  fontSize: bw * 0.036, letterSpacing: 1.4, color: "#f0c261",
                  textShadow: "0 1px 2px rgba(0,0,0,.85)",
                }}>
                  COMING SOON
                </div>
              )}
            </div>
          );
        }
        return (
          <img key={b.key} src={`${KIT}btn-${b.key}.png`} alt={b.key} draggable={false}
               role="button" {...hit} style={{ ...place, height: "auto", ...press }} />
        );
      })}
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
  // categories and the character behind it never shifts. Sized off the
  // TALLER row type (wood chips) for every category; stud rows center in
  // the same box instead of shrinking it.
  const rowH = chipW * 1.06;
  // Every category fits in two rows, so this area never needs to scroll.
  // It is deliberately NOT a scroll container: an overflow box whose top
  // edge sits flush on the studs clips their rim, selection ring and glow.
  const pad = rowH * 0.16;
  const optH = rowH * 2 + rowH * 0.26 + pad * 2;

  return (
    <div style={{ position: "relative", width, fontFamily: T.font, userSelect: "none",
                  paddingBottom: width * 0.10, ...style }}>
      <StonePanel edge={edge} corner={edge * 2.05}>
        <WoodBar height={width * 0.092} fontSize={width * 0.044}
                 style={{ margin: `0 ${width * 0.14}px ${width * 0.02}px`, cursor: "default" }}>
          WARDROBE
        </WoodBar>

        {/* category picker — carved tabs, one row */}
        <div style={{ display: "flex", gap: width * 0.013, justifyContent: "center",
                      flexWrap: "wrap", marginBottom: width * 0.022 }}>
          {groups.map((g) => (
            <CatTab key={g.key} label={g.label} sel={g.key === cat}
                    h={width * 0.068} onPick={() => setCat(g.key)} />
          ))}
        </div>

        {/* options for the active category */}
        <div style={{ height: optH, boxSizing: "border-box", padding: `${pad}px 0`,
                      display: "flex", flexWrap: "wrap", justifyContent: "center",
                      alignContent: "center",
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

        <WoodBar onClick={onRandom} height={width * 0.088} fontSize={width * 0.04}
                 style={{ margin: `${width * 0.02}px ${width * 0.17}px ${width * 0.035}px` }}>
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


// ------------------------------------------------------------- Almanac
// The "game bible" popup: what each crop costs, sells for, and earns in
// level gems. Deliberately small — three rows and one footnote, no walls
// of text. Opened from the info stud on the Player Profile.
export function Almanac({ crops = [], width = 340, onClose, style }) {
  const [closeDown, setCloseDown] = React.useState(false);
  const edge = width * 0.086;
  const fs = width * 0.041;
  const cell = { flex: "0 0 16.5%", textAlign: "center", fontWeight: 800, fontSize: fs * 1.08, color: "#3a2c19", textShadow: "0 1px 0 rgba(255,252,242,.75)" };
  return (
    <div style={{ position: "relative", width, fontFamily: T.font, userSelect: "none",
                  paddingBottom: width * 0.10, ...style }}>
      <StonePanel edge={edge} corner={edge * 2.05}>
        <WoodBar height={width * 0.115} fontSize={width * 0.05}
                 style={{ margin: `0 ${width * 0.06}px ${width * 0.045}px`, cursor: "default" }}>
          GARDENER'S ALMANAC
        </WoodBar>

        {/* header: what each column means */}
        <div style={{ display: "flex", alignItems: "center", padding: `0 ${width * 0.015}px`, marginBottom: width * 0.02 }}>
          <div style={{ flex: "1 1 auto" }} />
          <div style={{ ...cell, fontSize: fs * 0.82, letterSpacing: 1, color: "#6b5232" }}>SEED<br/>✦</div>
          <div style={{ ...cell, fontSize: fs * 0.82, letterSpacing: 1, color: "#6b5232" }}>SELL
            <span style={{ display: "flex", justifyContent: "center", marginTop: 2 }}><CoinIcon size={fs * 1.25} /></span>
          </div>
          <div style={{ ...cell, fontSize: fs * 0.82, letterSpacing: 1, color: "#6b5232" }}>HARVEST<br/>💎</div>
        </div>

        {crops.map((cr) => (
          <div key={cr.key} style={{
            display: "flex", alignItems: "center", padding: `${width * 0.012}px ${width * 0.015}px`,
            borderRadius: 10, marginBottom: width * 0.014,
            background: "rgba(90,60,25,.10)",
          }}>
            <img src={`${KIT}inv-basket-${cr.key}.png`} alt="" draggable={false}
                 style={{ width: width * 0.112, height: width * 0.112, objectFit: "contain", flex: "0 0 auto" }} />
            <div style={{ flex: "1 1 auto", minWidth: 0, fontWeight: 800, fontSize: fs * 1.02,
                          color: "#241a0e", textShadow: "0 1px 0 rgba(255,252,242,.85)",
                          whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                          paddingLeft: width * 0.015 }}>{cr.name}</div>
            <div style={cell}>{cr.cost}</div>
            <div style={cell}>{cr.sell}</div>
            <div style={cell}>+{cr.gems}</div>
          </div>
        ))}

        <div style={{
          margin: `${width * 0.03}px ${width * 0.02}px ${width * 0.05}px`,
          fontSize: fs * 0.92, lineHeight: 1.55, fontWeight: 600, textAlign: "center",
          color: "#5f584a", textShadow: "0 1px 0 rgba(255,255,255,.35)",
        }}>
          <div>Buy seeds with XP at Rosie's in town.</div>
          <div>Sell fruit for gold at the Berry Market.</div>
          <div>Gems fill your level bar with every harvest.</div>
        </div>
      </StonePanel>

      {/* CLOSE hangs off the bottom frame, same as the profile board */}
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


// ------------------------------------------------------------ Toolworks
// Grimble's shop on the painted board (toolworks-v2.png): names, blurbs and
// the hold-hint are baked into the art; the live layer is the wallet pills —
// HOLD one and it fills gold to complete the purchase (the game's standard
// spend gesture). Locked / info rows open an explainer via onExplain.
const TOOLS_ROW_C = [0.350, 0.498, 0.646, 0.786];
const TOOLS_CLOSE = { x0: 0.16, x1: 0.84, y0: 0.896, y1: 0.954 };
const TOOLS_ASPECT = 757 / 1289;

export function Toolworks({ items = [], xp = 0, width = 340, onBuy, onExplain, onClose, style }) {
  const [hold, setHold] = React.useState(null); // { key, pct }
  const [closeDown, setCloseDown] = React.useState(false);
  const timer = React.useRef(null);
  const stopHold = () => { if (timer.current) clearInterval(timer.current); timer.current = null; setHold(null); };
  React.useEffect(() => stopHold, []);
  const startHold = (it) => {
    stopHold();
    const t0 = performance.now();
    timer.current = setInterval(() => {
      const pct = Math.min(1, (performance.now() - t0) / 750);
      setHold({ key: it.key, pct });
      if (pct >= 1) { stopHold(); onBuy && onBuy(it.key); }
    }, 33);
  };
  const ART = `${KIT}toolworks-v2.png`;
  const ready = useArtReady(ART);
  const pillH = width * 0.088;
  return (
    <div
      style={{
        position: "relative", width, aspectRatio: String(TOOLS_ASPECT),
        fontFamily: T.font, userSelect: "none",
        filter: "drop-shadow(0 16px 32px rgba(25,20,10,.55))",
        opacity: ready ? 1 : 0, transition: "opacity .18s ease",
        ...style,
      }}
    >
      <img src={ART} alt="Grimble's Toolworks" draggable={false}
           style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
      {items.map((it, i2) => {
        const c = TOOLS_ROW_C[i2];
        if (c == null) return null;
        const afford = it.cost != null && xp >= it.cost;
        const holding = hold && hold.key === it.key;
        if (it.kind === "owned") {
          return (
            <div key={it.key} style={{
              position: "absolute", right: "9.5%", top: `${c * 100}%`, transform: "translateY(-50%)",
              fontWeight: 800, fontSize: width * 0.042, color: "#8ee07a",
              textShadow: "0 1px 3px rgba(15,30,8,.9)", letterSpacing: 0.5,
            }}>OWNED ✓</div>
          );
        }
        const dim = it.kind === "locked" || (it.kind === "buy" && !afford);
        return (
          <div
            key={it.key}
            role="button"
            onPointerDown={(e) => {
              e.stopPropagation();
              if (it.kind === "locked") { onExplain && onExplain(it.key); return; }
              if (it.kind === "info") { onExplain && onExplain(it.key); return; }
              if (!afford) { onExplain && onExplain(it.key + ":poor"); return; }
              startHold(it);
            }}
            onPointerUp={stopHold}
            onPointerLeave={stopHold}
            onPointerCancel={stopHold}
            style={{
              position: "absolute", right: "9.5%", top: `${c * 100}%`,
              transform: `translateY(-50%) ${holding ? "scale(1.06)" : "scale(1)"}`,
              cursor: "pointer", WebkitTapHighlightColor: "transparent",
              opacity: dim ? 0.62 : 1,
              filter: it.kind === "locked" ? "grayscale(.45)" : "none",
              transition: holding ? "transform .1s ease-out" : "transform .22s cubic-bezier(.2,1.6,.4,1)",
              textAlign: "center",
            }}
          >
            <div style={{ position: "relative", overflow: "hidden", borderRadius: pillH * 0.5 }}>
              <PlatePill kind="xp" value={it.cost} height={pillH} />
              {holding && (
                <div style={{
                  position: "absolute", left: 0, top: 0, bottom: 0, width: `${hold.pct * 100}%`,
                  background: "rgba(255,214,120,.5)", pointerEvents: "none",
                  boxShadow: "0 0 12px rgba(255,199,102,.8)",
                }} />
              )}
            </div>
            {it.kind === "locked" && (
              <span style={{ position: "absolute", right: -6, top: -9, fontSize: width * 0.045,
                             filter: "drop-shadow(0 1px 2px rgba(20,12,4,.6))" }}>🔒</span>
            )}
            {it.kind === "info" && (
              <div style={{ fontSize: width * 0.026, letterSpacing: 1, fontWeight: 800, color: "#f7e7c8",
                            textShadow: "0 1px 2px rgba(35,18,4,.8)", marginTop: 3 }}>IN BUILD MODE</div>
            )}
          </div>
        );
      })}
      <div
        role="button"
        onPointerDown={() => setCloseDown(true)}
        onPointerUp={() => setCloseDown(false)}
        onPointerLeave={() => setCloseDown(false)}
        onClick={onClose}
        style={{
          position: "absolute",
          left: `${TOOLS_CLOSE.x0 * 100}%`, width: `${(TOOLS_CLOSE.x1 - TOOLS_CLOSE.x0) * 100}%`,
          top: `${TOOLS_CLOSE.y0 * 100}%`, height: `${(TOOLS_CLOSE.y1 - TOOLS_CLOSE.y0) * 100}%`,
          cursor: "pointer", WebkitTapHighlightColor: "transparent",
        }}
      />
      {closeDown && (
        <div style={{
          position: "absolute", inset: 0, pointerEvents: "none",
          clipPath: `inset(${TOOLS_CLOSE.y0 * 100}% ${(1 - TOOLS_CLOSE.x1) * 100}% ${(1 - TOOLS_CLOSE.y1) * 100}% ${TOOLS_CLOSE.x0 * 100}%)`,
          transform: "scale(.98) translateY(2px)",
          transformOrigin: `50% ${((TOOLS_CLOSE.y0 + TOOLS_CLOSE.y1) / 2) * 100}%`,
          filter: "brightness(.85)",
        }}>
          <img src={ART} alt="" draggable={false}
               style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
        </div>
      )}
    </div>
  );
}


// -------------------------------------------------------- InventoryBoard
// One inventory for every map, on the painted parchment board with the
// "Inventory" plank hanging off the top. Three rows — Regular Seeds,
// Basket, Rare Seeds — with per-map availability: rows the current map
// can't use render greyed and report taps via onLocked instead of picking.
const INVB_ASPECT = 844 / 1006;
const INV_PLANK_ASPECT = 1244 / 282;

export function InventoryBoard({ width = 340, mode = "home", seeds = [], basket = [], rare = [],
                                 onLocked, style }) {
  const ready = useArtReady(`${KIT}inv-board-v2.png`, `${KIT}inv-title-plank.png`);
  const rareLocked = mode !== "community";
  const homeLocked = mode === "community";
  const label = (txt) => (
    <div style={{ fontFamily: T.font, fontWeight: 800, fontSize: width * 0.044, letterSpacing: 1.2,
                  color: "#4b3a22", textShadow: "0 1px 0 rgba(255,250,238,.8)",
                  margin: `0 0 ${width * 0.012}px` }}>{txt}</div>
  );
  const tile = (it, w, disabled) => (
    <div
      key={it.key}
      role="button"
      onClick={() => { if (disabled) { onLocked && onLocked(); } else it.onClick && it.onClick(); }}
      style={{
        position: "relative", width: w, flex: "0 0 auto", cursor: "pointer",
        WebkitTapHighlightColor: "transparent",
        borderRadius: w * 0.16,
        boxShadow: it.selected && !disabled ? "0 0 0 3px #f0c261, 0 0 14px rgba(247,199,102,.75)" : "none",
      }}
    >
      <img src={`${KIT}inv-${it.art}-${it.key}.png`} alt={it.key} draggable={false}
           style={{ display: "block", width: "100%", height: "auto" }} />
      {/* count sits INSIDE the tile's baked badge circle (centre 82.5%/15.5%) */}
      <div style={{ position: "absolute", left: "82.5%", top: "15.5%", transform: "translate(-50%,-50%)",
                    fontFamily: T.font, fontWeight: 800, fontSize: w * 0.165, color: "#fff",
                    textShadow: "0 1px 2px rgba(30,15,4,.9)", pointerEvents: "none", lineHeight: 1 }}>
        <CountBadge value={it.count} />
      </div>
    </div>
  );
  const row = (txt, items, w, disabled) => (
    <div style={{ opacity: disabled ? 0.4 : 1, filter: disabled ? "grayscale(.85)" : "none" }}>
      {label(txt)}
      <div style={{ display: "flex", gap: width * 0.025, justifyContent: "flex-start" }}>
        {items.map((it) => tile(it, w, disabled))}
      </div>
    </div>
  );
  return (
    <div style={{ position: "relative", width, aspectRatio: String(INVB_ASPECT),
                  fontFamily: T.font, userSelect: "none",
                  filter: "drop-shadow(0 16px 32px rgba(25,20,10,.55))",
                  opacity: ready ? 1 : 0, transition: "opacity .18s ease", ...style }}>
      <img src={`${KIT}inv-board-v2.png`} alt="Inventory" draggable={false}
           style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
      {/* the plank hangs off the top, centred */}
      <img src={`${KIT}inv-title-plank.png`} alt="" draggable={false}
           style={{ position: "absolute", left: "50%", transform: "translateX(-50%)",
                    top: `-${(width * 0.66 / INV_PLANK_ASPECT) * 0.52}px`, width: "66%",
                    filter: "drop-shadow(0 5px 9px rgba(30,20,10,.5))", zIndex: 2 }} />
      <div style={{ position: "absolute", left: "10%", right: "10%", top: "9%", bottom: "9%",
                    display: "flex", flexDirection: "column", justifyContent: "flex-start",
                    gap: width * 0.055 }}>
        {row("Regular Seeds", seeds, width * 0.185, homeLocked)}
        {row("Basket", basket, width * 0.185, homeLocked)}
        {row("Rare Seeds", rare, width * 0.155, rareLocked)}
      </div>
    </div>
  );
}

// ------------------------------------------------------- HarvestForecast
// "What will this garden bring in?" — the card the picnic table by the
// chapel hands the player. One number, one line of context, and a per-fruit
// breakdown; deliberately no rates, no maths, no expiry table.
export function HarvestForecast({
  total = 0, trees = 0, ripening = 0, rows = [], width = 330, onClose, style,
}) {
  const n = (v) => v.toLocaleString("en-US");
  const edge = width * 0.075;
  return (
    <div style={{ position: "relative", width, fontFamily: T.font, userSelect: "none", ...style }}>
      <StonePanel edge={edge} corner={edge * 2.05}>
        <div style={{ textAlign: "center", padding: "2px 2px 4px" }}>
          <div style={{
            fontWeight: 800, fontSize: width * 0.043, letterSpacing: 1.8,
            color: "#7a4a22", textShadow: "0 1px 0 rgba(255,250,238,.6)",
          }}>
            NEXT 24 HOURS
          </div>

          {trees === 0 ? (
            <div style={{
              fontSize: width * 0.043, lineHeight: 1.45, fontWeight: 600,
              color: "#4a3520", margin: `${width * 0.05}px ${width * 0.02}px ${width * 0.045}px`,
            }}>
              Nothing is growing in the blessed soil yet. Earn a planting from
              Old Eli, then sow a rare seed to start the harvest.
            </div>
          ) : (
            <>
              <div style={{
                display: "flex", alignItems: "center", justifyContent: "center",
                gap: width * 0.022, marginTop: width * 0.028,
              }}>
                {["glowberry", "starberry", "dawnberry", "gloryberry"].map((k) => (
                  <img key={k} src={`${KIT}fruit-${k}-sm.png`} alt="" draggable={false}
                       style={{ width: width * 0.055, height: width * 0.055, objectFit: "contain",
                                filter: "drop-shadow(0 1px 2px rgba(40,60,30,.45))" }} />
                ))}
              </div>
              <div style={{
                fontWeight: 900, fontSize: width * 0.155, lineHeight: 1.05,
                color: "#2f6a26", marginTop: width * 0.012,
                textShadow: "0 2px 0 rgba(255,252,240,.6), 0 3px 6px rgba(40,70,30,.28)",
              }}>
                {n(total)}
              </div>
              <div style={{
                fontWeight: 800, fontSize: width * 0.04, letterSpacing: 2.2,
                color: "#5f7a3f", marginTop: -width * 0.004,
              }}>
                BERRIES
              </div>
              <div style={{
                fontSize: width * 0.04, fontWeight: 700, color: "#6d5233",
                marginTop: width * 0.018,
              }}>
                from {trees} {trees === 1 ? "tree" : "trees"} in the blessed soil
              </div>
              {ripening > 0 && (
                <div style={{
                  fontSize: width * 0.036, fontWeight: 700, color: "#8a7350",
                  marginTop: width * 0.006,
                }}>
                  {ripening} of them {ripening === 1 ? "is" : "are"} still ripening
                </div>
              )}

              <div style={{
                display: "flex", flexDirection: "column", gap: width * 0.014,
                margin: `${width * 0.05}px 0 ${width * 0.05}px`,
              }}>
                {rows.map((r) => (
                  <div key={r.key} style={{
                    display: "flex", alignItems: "center", gap: width * 0.03,
                    padding: `${width * 0.017}px ${width * 0.04}px`,
                    borderRadius: width * 0.026,
                    background: "linear-gradient(180deg, rgba(255,250,236,.5), rgba(190,166,132,.34))",
                    border: "1.5px solid rgba(122,96,60,.42)",
                    boxShadow: "inset 0 1px 0 rgba(255,252,242,.6)",
                  }}>
                    <img src={`${KIT}fruit-${r.key}-sm.png`} alt="" draggable={false}
                         style={{ width: width * 0.07, height: width * 0.07, objectFit: "contain",
                                  filter: "drop-shadow(0 1px 2px rgba(40,60,30,.4))" }} />
                    <div style={{
                      flex: "1 1 auto", textAlign: "left", fontWeight: 800,
                      fontSize: width * 0.042, color: "#3a2c19",
                      textShadow: "0 1px 0 rgba(255,252,242,.7)",
                    }}>
                      {r.name}
                    </div>
                    <div style={{
                      fontWeight: 900, fontSize: width * 0.046, color: "#2f6a26",
                      textShadow: "0 1px 0 rgba(255,252,242,.7)",
                    }}>
                      {n(r.n)}
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}

          <div
            role="button"
            onClick={onClose}
            style={{
              cursor: "pointer", WebkitTapHighlightColor: "transparent",
              display: "inline-block", padding: `${width * 0.028}px ${width * 0.12}px ${width * 0.031}px`,
              borderRadius: width * 0.03, fontSize: width * 0.046, fontWeight: 800,
              background: "linear-gradient(180deg, #a8794a, #7d5330 62%, #63401f)",
              border: "2px solid #f0c261", color: "#ffe9b8",
              textShadow: "0 1px 2px rgba(35,18,4,.75)",
              boxShadow: "inset 0 2px 0 rgba(255,226,180,.3), 0 3px 6px rgba(30,20,10,.45)",
            }}
          >
            GOT IT
          </div>
        </div>
      </StonePanel>
    </div>
  );
}

// -------------------------------------------------------- CharacterStudio
// The dress-up board: live avatar on the left, five carved category slabs on
// the right. Tapping a slab expands its items directly beneath it — an
// accordion, so only one list is ever open and the board never scrolls two
// things at once.
//
// Item tiles are baked renders of the REAL avatar meshes (public/ui/kit/opt,
// built by tools/bake-item-icons.mjs), so a tile shows the item itself
// rather than a stand-in glyph or a character wearing it.
const STUDIO_ASPECT = 913 / 1018;
const STUDIO_PAD = { l: 0.075, r: 0.065, t: 0.125, b: 0.085 };
const CAT_ASPECT = 1273 / 254;

function ItemTile({ src, label, sel, size, onPick }) {
  const [down, setDown] = React.useState(false);
  return (
    <div
      role="button"
      onPointerDown={() => setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      onClick={onPick}
      style={{
        width: size, height: size, boxSizing: "border-box", flex: "0 0 auto",
        cursor: "pointer", WebkitTapHighlightColor: "transparent",
        borderRadius: size * 0.16, position: "relative", overflow: "hidden",
        background: "linear-gradient(180deg, rgba(255,250,236,.62), rgba(188,163,127,.42))",
        border: `${Math.max(2, size * 0.045)}px solid ${sel ? "#f0c261" : "rgba(120,94,58,.55)"}`,
        boxShadow: sel
          ? `0 0 ${size * 0.22}px rgba(247,199,102,.8), inset 0 1px 0 rgba(255,252,242,.7)`
          : "inset 0 1px 0 rgba(255,252,242,.6), 0 2px 4px rgba(60,44,22,.28)",
        transform: down ? "scale(.93)" : sel ? "scale(1.04)" : "scale(1)",
        transition: down ? "transform .07s ease-out" : "transform .18s cubic-bezier(.2,1.6,.4,1), box-shadow .18s",
      }}
    >
      {src ? (
        <img src={src} alt={label} draggable={false}
             style={{ position: "absolute", inset: "6%", width: "88%", height: "88%", objectFit: "contain" }} />
      ) : (
        <div style={{
          position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center",
          fontFamily: T.font, fontWeight: 800, fontSize: size * 0.24, color: "#7a6242",
          textShadow: "0 1px 0 rgba(255,252,242,.7)",
        }}>None</div>
      )}
    </div>
  );
}

export function CharacterStudio({
  avatar, cats = [], outfit = {}, open, onToggle, onPick, onConfirm, onCancel,
  width = 360, style,
}) {
  const [pressed, setPressed] = React.useState(null);
  const boardH = width / STUDIO_ASPECT;
  const inX = width * STUDIO_PAD.l;
  const inW = width * (1 - STUDIO_PAD.l - STUDIO_PAD.r);
  const inY = boardH * STUDIO_PAD.t;
  const inH = boardH * (1 - STUDIO_PAD.t - STUDIO_PAD.b);
  const colGap = inW * 0.04;
  const avaW = inW * 0.34;
  const listW = inW - avaW - colGap;
  const slabH = listW / CAT_ASPECT;
  const tile = listW * 0.29;

  const btn = (src, key, w, onTap) => (
    <img
      src={`${KIT}${src}`} alt={key} draggable={false} role="button"
      onPointerDown={() => setPressed(key)}
      onPointerUp={() => setPressed(null)}
      onPointerLeave={() => setPressed(null)}
      onClick={onTap}
      style={{
        width: w, height: "auto", cursor: "pointer", WebkitTapHighlightColor: "transparent",
        transform: pressed === key ? "translateY(2px) scale(.975)" : "none",
        filter: pressed === key ? "brightness(.9)" : "drop-shadow(0 4px 7px rgba(30,20,8,.45))",
        transition: "transform .08s ease, filter .12s ease",
      }}
    />
  );

  return (
    <div style={{ position: "relative", width, fontFamily: T.font, userSelect: "none",
                  paddingBottom: width * 0.085, ...style }}>
      <img src={`${KIT}studio-board.png`} alt="Character Studio" draggable={false}
           style={{ display: "block", width: "100%", height: "auto",
                    filter: "drop-shadow(0 16px 32px rgba(25,20,10,.55))" }} />

      {/* live character — the render is trimmed to its silhouette, so it can
          be scaled to fill the pane rather than floating inside its margin */}
      <div style={{
        position: "absolute", left: inX, top: inY, width: avaW, height: inH,
        display: "flex", flexDirection: "column", alignItems: "center",
        justifyContent: "center", gap: avaW * 0.04,
      }}>
        {avatar && (
          <img src={avatar} alt="Your gardener" draggable={false}
               style={{ maxWidth: "100%", maxHeight: inH * 0.82, width: "auto", height: "auto",
                        display: "block", filter: "drop-shadow(0 8px 12px rgba(60,44,20,.45))" }} />
        )}
        <div style={{
          width: avaW * 0.66, height: avaW * 0.13, borderRadius: "50%", flex: "0 0 auto",
          background: "radial-gradient(ellipse at center, rgba(78,58,30,.36), rgba(78,58,30,0) 70%)",
        }} />
      </div>

      {/* categories */}
      <div style={{
        position: "absolute", left: inX + avaW + colGap, top: inY,
        width: listW, height: inH, overflowY: "auto", overscrollBehavior: "contain",
        display: "flex", flexDirection: "column", gap: slabH * 0.17,
      }}>
        {cats.map((c) => {
          const isOpen = open === c.key;
          return (
            <div key={c.key} style={{ flex: "0 0 auto" }}>
              <img
                src={`${KIT}studio-cat-${c.key}.png`}
                alt={c.key}
                draggable={false}
                role="button"
                onClick={() => onToggle && onToggle(isOpen ? null : c.key)}
                style={{
                  display: "block", width: "100%", height: "auto", cursor: "pointer",
                  WebkitTapHighlightColor: "transparent",
                  filter: isOpen
                    ? "drop-shadow(0 0 6px #ffd98a) drop-shadow(0 0 13px rgba(247,199,102,.7)) brightness(1.05)"
                    : "drop-shadow(0 2px 4px rgba(40,30,14,.4))",
                  transition: "filter .2s ease",
                }}
              />
              {isOpen && (
                <div style={{
                  display: "flex", flexWrap: "wrap", gap: tile * 0.13,
                  padding: `${tile * 0.16}px ${tile * 0.06}px ${tile * 0.2}px`,
                  animation: "byStudioOpen .2s ease-out both",
                }}>
                  {c.items.map((it) => (
                    <ItemTile
                      key={it.v} src={it.icon} label={it.name} size={tile}
                      sel={outfit[c.slot] === it.v}
                      onPick={() => onPick && onPick(c.slot, it.v)}
                    />
                  ))}
                  {(c.swatches || []).map((sw) => (
                    <div key={sw.slot} style={{ width: "100%", display: "flex", flexWrap: "wrap",
                                                gap: tile * 0.11, marginTop: tile * 0.08 }}>
                      <div style={{ width: "100%", fontSize: tile * 0.2, fontWeight: 800,
                                    letterSpacing: 1, color: "#7a6242",
                                    textShadow: "0 1px 0 rgba(255,252,242,.7)" }}>
                        {sw.label}
                      </div>
                      {sw.list.map((col) => (
                        <Stud key={col} color={col} size={tile * 0.46}
                              sel={outfit[sw.slot] === col}
                              onPick={() => onPick && onPick(sw.slot, col)} />
                      ))}
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* confirm / cancel hang off the bottom rail, as in the board art */}
      <div style={{
        position: "absolute", left: 0, right: 0, bottom: width * 0.012,
        display: "flex", alignItems: "flex-end", justifyContent: "center",
        gap: width * 0.022,
      }}>
        {btn("studio-confirm.png", "confirm", width * 0.44, onConfirm)}
        {btn("studio-cancel.png", "cancel", width * 0.19, onCancel)}
      </div>

      <style>{`
        @keyframes byStudioOpen {
          from { opacity: 0; transform: translateY(-4px) }
          to   { opacity: 1; transform: translateY(0) }
        }
      `}</style>
    </div>
  );
}
