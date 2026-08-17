// ------------------------------------------------------------ ReadingPlayer
// The "read to earn XP" mini player. It rides in at the bottom of the screen
// on a level-up, BEFORE the LEVEL UP badge: play a section of Scripture and
// answer one question, or skip and take the badge now.
//
// Deliberately NOT a modal. The dock and the captions are pointer-transparent
// except for their own controls, so the player can keep walking, planting and
// feeding Ember while the passage reads.
//
// XP is never counted here. The green bar is a *promise* — it fills with the
// audio so the reward feels live — and the real credit lands server-side in
// by_finish_reading / by_answer_reading, which are idempotent.
import React from "react";
import { T, StonePanel, SparkIcon } from "./ui-kit.jsx";

const KIT = "/ui/kit/";
const GREEN = { lo: "#2f9c1c", mid: "#4ddb2f", hi: "#c2ff7a" };

// One Audio element, re-sourced per verse. iOS only trusts an element that
// was unlocked by a real tap — building a fresh Audio per verse gets the
// second one silently blocked.
function useVersePlayer(verses, { onVerse, onVerseDone, onEnd, duck }) {
  const el = React.useRef(null);
  const warm = React.useRef(null);
  const idx = React.useRef(0);
  const dead = React.useRef(false);
  // Callbacks arrive as fresh closures on every parent render. Route them
  // through a ref so nothing here changes identity — a `stop` that churned
  // would tear the audio down mid-verse on an unrelated re-render.
  const cb = React.useRef(null);
  cb.current = { onVerse, onVerseDone, onEnd, duck };

  const stop = React.useCallback(() => {
    const a = el.current;
    if (a) { a.onended = null; a.onerror = null; try { a.pause(); } catch (e) {} }
    try { cb.current.duck && cb.current.duck(false); } catch (e) {}
  }, []);

  React.useEffect(() => () => { dead.current = true; stop(); }, [stop]);

  const playFrom = React.useCallback((i) => {
    if (dead.current) return;
    if (i >= verses.length) { stop(); cb.current.onEnd && cb.current.onEnd(); return; }
    // a verse only counts once its audio has actually played out, so the
    // bank happens on the way IN to the next one
    if (i > 0 && cb.current.onVerseDone) cb.current.onVerseDone(i);
    idx.current = i;
    cb.current.onVerse && cb.current.onVerse(i);
    const a = el.current || (el.current = new Audio());
    a.onended = () => playFrom(i + 1);
    // a missing or unplayable clip must not strand the reading
    a.onerror = () => playFrom(i + 1);
    a.src = verses[i].url;
    a.play().catch(() => playFrom(i + 1));
    // warm the next clip's HTTP cache so the gap between verses stays short
    if (verses[i + 1]) {
      warm.current = warm.current || new Audio();
      warm.current.preload = "auto";
      warm.current.src = verses[i + 1].url;
      try { warm.current.load(); } catch (e) {}
    }
  }, [verses, stop]);

  const start = React.useCallback((from = 0) => {
    try { cb.current.duck && cb.current.duck(true); } catch (e) {}
    playFrom(Math.max(0, Math.min(verses.length - 1, from)));
  }, [playFrom, verses.length]);

  // seconds consumed so far, across the whole section
  const elapsed = React.useCallback(() => {
    let t = 0;
    for (let i = 0; i < idx.current; i++) t += verses[i].seconds || 0;
    const cur = el.current && !el.current.paused ? el.current.currentTime || 0 : 0;
    return t + Math.min(cur, verses[idx.current]?.seconds || cur);
  }, [verses]);

  return { start, stop, elapsed, at: () => idx.current };
}

// ------------------------------------------------------------------ pieces

function GemStrip({ gems, active, size = 13 }) {
  return (
    <div style={{ display: "flex", gap: size * 0.26, alignItems: "center" }}>
      {gems.map((g, i) => (
        <img
          key={i}
          src={`${KIT}level-gem.png`}
          alt=""
          draggable={false}
          style={{
            width: size, height: size * 1.1, objectFit: "contain",
            opacity: g.done ? 1 : 0.26,
            filter: g.done
              ? "drop-shadow(0 0 4px rgba(120,200,255,.85))"
              : "grayscale(1) brightness(.65)",
            animation: g.ordinal === active && !g.done ? "byReadGemPulse 1.5s ease-in-out infinite" : "none",
          }}
        />
      ))}
    </div>
  );
}

// The bar fills with the audio; the pips sit at the verse boundaries, in
// their true time positions, so they are unevenly spaced exactly as the
// verses are. A pip lights when its verse is banked. The number is what has
// ACTUALLY been credited, not a projection — it steps at each pip rather
// than sliding, so the bar never promises XP you would lose by stopping a
// second later.
function XpBar({ pct, xp, marks = [], done = 0, height = 15 }) {
  return (
    <div
      style={{
        position: "relative", height, borderRadius: 999, overflow: "hidden",
        background: "#2e2416",
        border: "2px solid #6d5233",
        boxShadow: "inset 0 2px 5px rgba(0,0,0,.6), 0 1px 0 rgba(255,240,200,.25)",
      }}
    >
      <div
        style={{
          position: "absolute", left: 0, top: 0, bottom: 0,
          width: `${Math.max(0, Math.min(1, pct)) * 100}%`,
          background: `linear-gradient(180deg, ${GREEN.hi} 0%, ${GREEN.mid} 52%, ${GREEN.lo} 100%)`,
          boxShadow: `0 0 10px rgba(120,255,90,.9), inset 0 1px 0 rgba(255,255,255,.7)`,
          // no width transition: the value is already re-driven every frame,
          // and a transition that restarts before it finishes never advances
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute", top: 0, bottom: 0, width: "38%",
            background: "linear-gradient(100deg, rgba(255,255,255,0), rgba(255,255,255,.78), rgba(255,255,255,0))",
            animation: "byReadShine 1.5s linear infinite",
          }}
        />
      </div>
      {/* verse checkpoints */}
      {marks.map((m, i) => {
        const banked = i < done;
        return (
          <div
            key={i}
            style={{
              position: "absolute", top: 0, bottom: 0, left: `${m * 100}%`,
              width: Math.max(2, height * 0.14), marginLeft: -Math.max(1, height * 0.07),
              // unbanked pips sit on the dark track, so they need to be light
              // to read at all — the whole scale should be visible up front
              background: banked ? "rgba(255,250,210,.95)" : "rgba(255,238,196,.26)",
              boxShadow: banked ? "0 0 5px rgba(255,244,180,.95)" : "none",
              transition: "background .18s ease, box-shadow .18s ease",
            }}
          />
        );
      })}
      <div
        style={{
          position: "absolute", inset: 0, display: "flex",
          alignItems: "center", justifyContent: "center",
          fontFamily: T.font, fontWeight: 800, fontSize: height * 0.72,
          color: "#f4ffe8", textShadow: "0 1px 2px rgba(10,40,10,.9)",
          letterSpacing: 0.3,
        }}
      >
        +{xp} XP
      </div>
    </div>
  );
}

// wood action button, sized by its label
function WoodAction({ children, onClick, tone = "wood", disabled, style }) {
  const [down, setDown] = React.useState(false);
  const skin = tone === "green"
    ? { bg: "linear-gradient(180deg,#5fd53d,#2f9c1c)", edge: "#1d6a12", ink: "#f4ffe8" }
    : { bg: "linear-gradient(180deg,#8a6438,#5d4123)", edge: "#3a2812", ink: T.cream };
  return (
    <div
      role="button"
      onClick={disabled ? undefined : onClick}
      onPointerDown={() => !disabled && setDown(true)}
      onPointerUp={() => setDown(false)}
      onPointerLeave={() => setDown(false)}
      style={{
        pointerEvents: "auto", cursor: disabled ? "default" : "pointer",
        WebkitTapHighlightColor: "transparent", userSelect: "none",
        padding: "8px 13px", borderRadius: 9,
        background: skin.bg, border: `2px solid ${skin.edge}`,
        boxShadow: down
          ? "inset 0 2px 4px rgba(0,0,0,.45)"
          : "inset 0 1px 0 rgba(255,255,255,.35), 0 3px 0 rgba(0,0,0,.32)",
        transform: down ? "translateY(2px)" : "none",
        transition: "transform .07s ease, box-shadow .07s ease",
        fontFamily: T.font, fontWeight: 800, fontSize: 13.5,
        color: skin.ink, textShadow: "0 1px 2px rgba(30,15,5,.7)",
        opacity: disabled ? 0.5 : 1,
        display: "flex", alignItems: "center", gap: 6, whiteSpace: "nowrap",
        ...style,
      }}
    >
      {children}
    </div>
  );
}

// ------------------------------------------------------------------- player

export default function ReadingPlayer({
  data,                 // { book, total, completed, gems, section }
  api,                  // window.YGTEEV_API
  duck,                 // (on) => duck the music bed
  sfx = {},             // { click, right, wrong, level }
  onXp,                 // (newTotalXp) => sync the wallet
  onDone,               // () => reading is over; parent fires the LEVEL UP badge
  onPhase,              // (phase) => so the world can gate on "mid-reading"
}) {
  const section = data?.section;
  const verses = section?.verses || [];
  const readXp = section?.read_xp ?? 250;

  const [phase, setPhase] = React.useState("offer"); // offer|play|question|result
  const [vi, setVi] = React.useState(0);
  const [pct, setPct] = React.useState(0);
  const [q, setQ] = React.useState(null);            // { prompt, choices, answer_xp }
  const [picked, setPicked] = React.useState(null);
  const [verdict, setVerdict] = React.useState(null); // { correct, correct_choice_index, awarded }
  const [busy, setBusy] = React.useState(false);

  const total = verses.reduce((s, v) => s + (v.seconds || 0), 0) || 1;

  // Where the last sitting got to, and what it was already paid.
  const resumeFrom = Math.min(section?.verses_done ?? 0, Math.max(0, verses.length - 1));
  const paidAlready = section?.read_xp_paid ?? 0;
  const [banked, setBanked] = React.useState(resumeFrom);      // verses credited
  const [earned, setEarned] = React.useState(paidAlready);     // XP actually credited
  // Checkpoint positions: cumulative audio time, so a pip sits exactly where
  // its verse ends rather than at an even fraction of the bar.
  const marks = React.useMemo(() => {
    let t = 0;
    return verses.map((v) => { t += v.seconds || 0; return t / total; });
  }, [verses, total]);
  // XP owed at a given verse count. Mirrors the server's target formula, so
  // the number on the bar matches what actually lands in the wallet.
  const xpAt = (n) => Math.round((readXp * n) / Math.max(1, verses.length));
  // a resumed section opens with its bar already part-filled
  React.useEffect(() => {
    if (!resumeFrom) return;
    const behind = verses.slice(0, resumeFrom).reduce((a, v) => a + (v.seconds || 0), 0);
    setPct(behind / total);
  }, [resumeFrom, verses, total]);

  const phaseCb = React.useRef(onPhase); phaseCb.current = onPhase;
  React.useEffect(() => { if (phaseCb.current) phaseCb.current(phase); }, [phase]);
  React.useEffect(() => () => { if (phaseCb.current) phaseCb.current(null); }, []);

  const finish = React.useCallback(async () => {
    setPct(1);
    setBusy(true);
    setBanked(verses.length);
    setEarned(readXp);
    try {
      // finishReading tops up to the full award, so the last verse — which
      // never gets an "on the way in" bank — is covered here
      const r = await api.finishReading(section.id);
      if (typeof r?.xp === "number") onXp && onXp(r.xp);
      setQ(r?.question || null);
      sfx.level && sfx.level();
      setPhase(r?.question ? "question" : "result");
      if (!r?.question) setVerdict({ correct: null, awarded: r?.awarded ?? 0 });
    } catch (e) {
      // the reading still happened — let them out rather than trapping them
      setPhase("result");
      setVerdict({ correct: null, awarded: 0, error: true });
    } finally {
      setBusy(false);
    }
  }, [api, section, onXp, sfx, verses.length, readXp]);

  // Fire-and-forget: by_credit_verses takes an absolute position, so a lost
  // call is covered by the next one and by the finish top-up. Awaiting here
  // would stall the audio behind the network.
  const bankVerse = React.useCallback((n) => {
    setBanked((b) => Math.max(b, n));
    setEarned(xpAt(n));
    Promise.resolve()
      .then(() => api.creditVerses(section.id, n))
      .then((r) => { if (typeof r?.xp === "number") onXp && onXp(r.xp); })
      .catch(() => { /* the finish top-up will settle it */ });
  }, [api, section, onXp, readXp, verses.length]); // eslint-disable-line react-hooks/exhaustive-deps

  const player = useVersePlayer(verses, {
    onVerse: setVi, onVerseDone: bankVerse, onEnd: finish, duck,
  });

  // drive the green bar off real playback time, one sample per frame
  React.useEffect(() => {
    if (phase !== "play") return;
    const tick = player.elapsed;
    let raf = 0;
    // elapsed() already sums every verse behind the cursor, including the
    // ones carried over from a previous sitting, so no resume offset here
    const step = () => { setPct(Math.min(1, tick() / total)); raf = requestAnimationFrame(step); };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [phase, player.elapsed, total]);

  if (!section) return null;

  const play = () => {
    sfx.click && sfx.click();
    setPhase("play");
    player.start(resumeFrom);
  };
  const leave = (played) => { player.stop(); onDone && onDone(played); };

  const answer = async (i) => {
    if (busy || picked != null) return;
    setPicked(i);
    setBusy(true);
    try {
      const r = await api.answerReading(section.id, i);
      if (typeof r?.xp === "number") onXp && onXp(r.xp);
      setVerdict(r);
      const sting = r?.correct ? sfx.right : sfx.wrong;
      if (sting) sting();
    } catch (e) {
      setVerdict({ correct: false, correct_choice_index: -1, awarded: 0, error: true });
    } finally {
      setBusy(false);
      setPhase("result");
    }
  };

  const gems = data.gems || [];
  const verse = verses[vi];

  return (
    <div
      style={{
        position: "fixed", left: 0, right: 0, bottom: 0, zIndex: 34,
        display: "flex", flexDirection: "column", alignItems: "center",
        // the panel's bottom corner stones jut ~15px past its box — leave
        // room or they read as clipped against the screen edge
        gap: 9, padding: `0 14px calc(22px + env(safe-area-inset-bottom, 0px))`,
        pointerEvents: "none", fontFamily: T.font,
        animation: "byReadIn .34s cubic-bezier(.2,1.1,.4,1) both",
      }}
    >
      {/* ---- captions: the exact words being spoken, ESV ----
           No panel behind them — a board here would hide the character the
           player is still walking around. Legibility over any scene comes
           from a carved outline (stroke painted under the fill) instead. */}
      {phase === "play" && verse && (
        <div style={{ width: "min(430px, 96vw)", textAlign: "center", padding: "0 6px 2px" }}>
          <div style={{
            fontSize: 11, fontWeight: 800, letterSpacing: 1.2,
            color: "#ffe9b4", textTransform: "uppercase", marginBottom: 4,
            WebkitTextStroke: "3px rgba(28,16,6,.9)", paintOrder: "stroke fill",
            filter: "drop-shadow(0 2px 3px rgba(20,12,4,.6))",
          }}>
            {section.reference.replace(/:.*$/, "")}:{verse.verse} · ESV
          </div>
          <div
            key={verse.verse}
            style={{
              fontSize: 17, fontWeight: 800, lineHeight: 1.34,
              color: T.cream,
              WebkitTextStroke: "4.5px rgba(28,16,6,.92)", paintOrder: "stroke fill",
              filter: "drop-shadow(0 3px 5px rgba(20,12,4,.65))",
              animation: "byReadVerse .3s ease-out both",
            }}
          >
            {verse.text}
          </div>
        </div>
      )}

      {/* ---- the question ---- */}
      {(phase === "question" || phase === "result") && q && (
        <div style={{ width: "min(430px, 96vw)", pointerEvents: "auto" }}>
          <StonePanel edge={18} corner={34}>
            <div style={{ padding: "2px 0 2px" }}>
              <div style={{
                fontSize: 14.5, fontWeight: 800, lineHeight: 1.32, textAlign: "center",
                color: "#4a3520", textShadow: "0 1px 0 rgba(255,246,225,.5)", marginBottom: 9,
              }}>
                {q.prompt}
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                {(q.choices || []).map((c, i) => {
                  const isPicked = picked === i;
                  const isKey = verdict && verdict.correct_choice_index === i;
                  const state = !verdict ? "idle" : isKey ? "right" : isPicked ? "wrong" : "idle";
                  const ring = state === "right" ? "#2f9c1c" : state === "wrong" ? "#a8321a" : "#8a7350";
                  const fill = state === "right" ? "#4ddb2f" : state === "wrong" ? "#d4523a" : "#cbb695";
                  return (
                    <div
                      key={i}
                      role="button"
                      onClick={() => answer(i)}
                      style={{
                        display: "flex", alignItems: "center", gap: 9,
                        padding: "7px 10px", borderRadius: 8,
                        background: "linear-gradient(180deg,#8a6438,#5d4123)",
                        border: `2px solid ${state === "idle" ? "#3a2812" : ring}`,
                        boxShadow: state === "right"
                          ? "0 0 10px rgba(90,220,60,.6), inset 0 1px 0 rgba(255,255,255,.3)"
                          : "inset 0 1px 0 rgba(255,255,255,.28), 0 2px 0 rgba(0,0,0,.3)",
                        cursor: verdict ? "default" : "pointer",
                        WebkitTapHighlightColor: "transparent",
                        opacity: verdict && state === "idle" ? 0.55 : 1,
                        transition: "opacity .2s ease, border-color .2s ease, box-shadow .2s ease",
                      }}
                    >
                      <div style={{
                        flex: "0 0 auto", width: 21, height: 21, borderRadius: 999,
                        background: fill, border: `2px solid ${ring}`,
                        display: "flex", alignItems: "center", justifyContent: "center",
                        fontSize: 11.5, fontWeight: 900,
                        color: state === "idle" ? "#4a3520" : "#fff",
                        textShadow: state === "idle" ? "none" : "0 1px 1px rgba(0,0,0,.4)",
                        transition: "background .2s ease, border-color .2s ease",
                      }}>
                        {i + 1}
                      </div>
                      <div style={{
                        fontSize: 13.5, fontWeight: 700, lineHeight: 1.28,
                        color: T.cream, textShadow: "0 1px 2px rgba(30,15,5,.7)",
                      }}>
                        {c}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </StonePanel>
        </div>
      )}

      {/* ---- the dock ---- */}
      <div style={{ width: "min(430px, 96vw)" }}>
        <StonePanel edge={18} corner={34}>
          <div style={{ display: "flex", flexDirection: "column", gap: 7 }}>
            {/* title row */}
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <div style={{ minWidth: 0, flex: "1 1 auto" }}>
                <div style={{
                  fontSize: 10.5, fontWeight: 800, letterSpacing: 1.2,
                  color: "#8a6a42", textTransform: "uppercase",
                }}>
                  {section.reference}
                </div>
                <div style={{
                  fontSize: 15.5, fontWeight: 800, color: "#4a3520",
                  textShadow: "0 1px 0 rgba(255,246,225,.5)",
                  overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
                }}>
                  {section.title}
                </div>
              </div>
              <div style={{ flex: "0 0 auto", textAlign: "right" }}>
                <GemStrip gems={gems} active={section.ordinal} />
                <div style={{
                  fontSize: 9.5, fontWeight: 800, color: "#8a6a42",
                  letterSpacing: 0.6, marginTop: 2,
                }}>
                  {data.completed}/{data.total} SECTIONS
                </div>
              </div>
            </div>

            {/* progress / actions */}
            {phase === "offer" && (
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <WoodAction tone="green" onClick={play} style={{ flex: "1 1 auto", justifyContent: "center" }}>
                  <span style={{ fontSize: 12 }}>▶</span>
                  {resumeFrom > 0
                    ? `Resume — ${resumeFrom} of ${verses.length} verses · ${readXp - paidAlready} XP left`
                    : `Play to earn ${readXp} XP`}
                  <SparkIcon size={14} />
                </WoodAction>
                <WoodAction onClick={() => { sfx.click && sfx.click(); leave(false); }}>Skip</WoodAction>
              </div>
            )}

            {phase === "play" && (
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <div style={{ flex: "1 1 auto" }}>
                  <XpBar pct={pct} xp={earned} marks={marks} done={banked} />
                </div>
                <WoodAction onClick={() => { sfx.click && sfx.click(); leave(false); }}>Stop</WoodAction>
              </div>
            )}

            {phase === "question" && (
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <div style={{ flex: "1 1 auto" }}>
                  <XpBar pct={1} xp={earned} marks={marks} done={verses.length} />
                </div>
                <div style={{
                  fontSize: 11.5, fontWeight: 800, color: "#6d5233",
                  whiteSpace: "nowrap",
                }}>
                  +{q?.answer_xp ?? 250} for the answer
                </div>
              </div>
            )}

            {phase === "result" && (
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <div style={{
                  flex: "1 1 auto", display: "flex", alignItems: "center", gap: 6,
                  fontSize: 14, fontWeight: 800,
                  color: verdict?.correct ? "#2f7a18" : "#8a4a20",
                  textShadow: "0 1px 0 rgba(255,246,225,.5)",
                }}>
                  {verdict?.correct === true && <>Well read! <SparkIcon size={15} /> +{readXp + (verdict.awarded || 0)} XP</>}
                  {verdict?.correct === false && <>Not this time — <SparkIcon size={15} /> +{readXp} XP for reading</>}
                  {verdict?.correct == null && <><SparkIcon size={15} /> +{readXp} XP for reading</>}
                </div>
                <WoodAction tone="green" onClick={() => { sfx.click && sfx.click(); leave(true); }}>Done</WoodAction>
              </div>
            )}
          </div>
        </StonePanel>
      </div>

      <style>{`
        @keyframes byReadIn {
          from { opacity: 0; transform: translateY(26px) }
          to   { opacity: 1; transform: translateY(0) }
        }
        @keyframes byReadVerse {
          from { opacity: 0; transform: translateY(5px) }
          to   { opacity: 1; transform: translateY(0) }
        }
        @keyframes byReadShine {
          from { left: -40% }
          to   { left: 105% }
        }
        @keyframes byReadGemPulse {
          0%,100% { opacity: .3; transform: scale(1) }
          50%     { opacity: .8; transform: scale(1.14) }
        }
      `}</style>
    </div>
  );
}
