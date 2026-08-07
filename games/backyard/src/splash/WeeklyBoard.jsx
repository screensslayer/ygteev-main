// The weekly leaderboard, shared by the title splash and the in-game
// "Open League Board" button so both show exactly the same board.
//
// This file owns the DATA (useBoardData) plus the modal presentation.
// The splash renders the rows itself because its board is bottom-anchored
// and shares a frame with START GAME; the in-game one is a centred modal.

import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { T, StonePanel, StoneSlab, TabToggle, WoodRow, SquareButton } from "./ui-kit.jsx";

// Screenshot-harness sample rows (window.__BY_SPLASH_SAMPLE) — never shown
// in production builds, only when the headless tooling sets the flag.
const SAMPLE = [
  { rank: 1, name: "Master_Grower", score: 25 },
  { rank: 2, name: "DaisyChain", score: 22 },
  { rank: 3, name: "Party", score: 19 },
  { rank: 4, name: "Buggyr", score: 17 },
  { rank: 5, name: "Realknow", score: 14 },
];

export const toneForRank = (r) => (r === 1 ? "gold" : r === 2 ? "stone" : "wood");

// Staging preview: when the real board is empty, show the sample users so
// the design is always judgeable on device. Never active in production.
const IS_STAGING = typeof location !== "undefined" && /staging|localhost|127\.0\.0\.1/.test(location.hostname);

const fallbackRows = () => [
  ...SAMPLE.slice(0, 3).map((s) => ({ ...s, user_id: String(s.rank) })),
  { user_id: "me", me: true, name: "Me", rank: 7, score: 8 },
];

/**
 * Players + Groups rows for the weekly board.
 * Display contract: top 3 players, then a 4th "Me" bar carrying the current
 * user's rank and level total.
 */
export function useBoardData(hud) {
  const [players, setPlayers] = useState(null); // null = loading
  const profile = (typeof window !== "undefined" && window.YGTEEV?.profile) || {};
  const sample = typeof window !== "undefined" && window.__BY_SPLASH_SAMPLE;

  useEffect(() => {
    let dead = false;
    (async () => {
      if (sample) { setPlayers(fallbackRows()); return; }
      try {
        const api = window.YGTEEV_API;
        if (!api?.getSplashPlayers) {
          setPlayers(IS_STAGING ? fallbackRows() : []);
          return;
        }
        const d = await api.getSplashPlayers();
        if (dead) return;
        let all = (d?.rows || []).map((r) => ({
          user_id: r.user_id, rank: r.rank, name: r.name || "Gardener",
          score: r.score, avatar: r.avatar, me: r.user_id === profile.id,
        }));
        if (all.length === 0 && IS_STAGING) {
          all = SAMPLE.map((s) => ({ ...s, user_id: String(s.rank) }));
        }
        const top3 = all.slice(0, 3).map((r) => (r.me ? { ...r, name: "Me" } : r));
        let rows = top3;
        if (!top3.some((r) => r.me)) {
          const me = d?.me;
          rows = [...top3, {
            user_id: "me", me: true, name: "Me",
            rank: me?.rank ?? (IS_STAGING ? 7 : "—"),
            score: me?.score ?? (IS_STAGING ? 8 : 0),
            avatar: profile.avatarUrl,
          }];
        }
        setPlayers(rows);
      } catch {
        if (!dead) setPlayers(IS_STAGING ? fallbackRows() : []);
      }
    })();
    return () => { dead = true; };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const groupRows = useMemo(() => {
    const L = hud?.league || {};
    const live = Array.isArray(L.rows) && L.rows.length > 0;
    if (sample && !live) return SAMPLE.map((s, i) => ({ ...s, name: ["Oak Ridge Youth", "River Church", "The Grove", "Northside", "Kings Kids"][i], user_id: String(i) }));
    if (!live) return [];
    return [...L.rows]
      .sort((a, b) => (b.adjusted ?? b.berries) - (a.adjusted ?? a.berries))
      .slice(0, 5)
      .map((r, i) => ({
        user_id: r.id || String(i), rank: i + 1, name: r.name,
        score: r.berries, me: !!r.mine,
      }));
  }, [hud?.league, sample]);

  return { players, groupRows };
}

export function BoardRows({ rows, tab, S }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 * S, padding: `${4 * S}px ${8 * S}px` }}>
      {rows === null && <EmptyNote S={S}>Gathering this week's gardeners…</EmptyNote>}
      {Array.isArray(rows) && rows.length === 0 && (
        <EmptyNote S={S}>
          {tab === "players"
            ? "No gardeners have levelled up yet — harvest to earn gems!"
            : "No gardens on the board yet this week."}
        </EmptyNote>
      )}
      {Array.isArray(rows) && rows.map((r) => (
        <WoodRow
          key={r.user_id ?? r.rank}
          rank={r.rank}
          name={r.name}
          score={r.score}
          avatarUrl={r.avatar}
          tone={toneForRank(r.rank)}
          me={r.me}
          height={78 * S}
        />
      ))}
    </div>
  );
}

export function EmptyNote({ S = 0.56, children }) {
  return (
    <div
      style={{
        padding: `${40 * S}px ${30 * S}px`,
        textAlign: "center",
        fontFamily: T.font,
        fontWeight: 600,
        fontSize: 26 * S,
        color: "#5f584a",
        textShadow: "0 1px 0 rgba(255,255,255,.35)",
      }}
    >
      {children}
    </div>
  );
}

/** In-game modal — the same board the title screen shows, centred over the world. */
export default function WeeklyBoardModal({ hud, onClose }) {
  const [tab, setTab] = useState("players");
  const { players, groupRows } = useBoardData(hud);
  const rows = tab === "players" ? players : groupRows;

  const wrapRef = useRef(null);
  const [w, setW] = useState(Math.min(typeof window !== "undefined" ? window.innerWidth : 430, 560));
  useLayoutEffect(() => {
    const measure = () => { if (wrapRef.current) setW(wrapRef.current.clientWidth); };
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, []);
  const S = w / 768; // same design-unit scale as the splash

  return (
    <div
      onClick={onClose}
      style={{
        position: "fixed", inset: 0, zIndex: 60, fontFamily: T.font,
        background: "rgba(12,16,10,.55)",
        backdropFilter: "blur(4px)", WebkitBackdropFilter: "blur(4px)",
        display: "flex", alignItems: "center", justifyContent: "center",
        padding: "16px 8px", boxSizing: "border-box",
        animation: "byBoardIn .22s ease-out both",
      }}
    >
      <div
        ref={wrapRef}
        onClick={(e) => e.stopPropagation()}
        style={{ position: "relative", width: "min(560px, 96vw)", paddingTop: 60 * S }}
      >
        <StoneSlab
          style={{
            position: "absolute", top: 6 * S, left: "50%", transform: "translateX(-50%)",
            zIndex: 5, width: 470 * S,
          }}
        />
        <SquareButton
          size={72 * S}
          onClick={onClose}
          // pinned at the board's top-left, riding above the frame so the
          // painted corner stone stays visible underneath
          style={{ position: "absolute", left: 2 * S, top: 2 * S, zIndex: 6 }}
        />

        <StonePanel edge={46 * S} corner={94 * S}>
          <div style={{ display: "flex", flexDirection: "column", gap: 12 * S, paddingBottom: 30 * S }}>
            <TabToggle
              tabs={[{ key: "players", label: "Players" }, { key: "groups", label: "Groups" }]}
              active={tab}
              onChange={setTab}
              height={72 * S}
              fontSize={26 * S}
              style={{ margin: `${36 * S}px ${44 * S}px 0` }}
            />
            <BoardRows rows={rows} tab={tab} S={S} />
          </div>
        </StonePanel>
      </div>

      <style>{`
        @keyframes byBoardIn { from { opacity: 0 } to { opacity: 1 } }
      `}</style>
    </div>
  );
}
