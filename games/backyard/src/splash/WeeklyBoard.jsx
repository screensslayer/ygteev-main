// The leaderboard, shared by the title splash and the in-game "Open League
// Board" button so both show exactly the same board. The DISPLAY is all-time
// for now (players by level, groups by lifetime rare berries); the weekly
// tables keep collecting underneath for funds/payouts and a later weekly view.
//
// This file owns the DATA (useBoardData) and the shared presentation
// (ScrollBoard), plus the in-game modal wrapper. Both surfaces show the same
// top 20; the splash just caps the scroller against the viewport, since its
// board is bottom-anchored and shares a frame with START GAME.

import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { T, StonePanel, StoneSlab, TabToggle, WoodRow, SquareButton } from "./ui-kit.jsx";

// How deep each board goes. The RPCs return at least this many.
export const TOP_N = 20;

// What the score column actually means, per tab.
const SCORE_LABEL = { players: "LEVELS", groups: "RARE BERRIES" };

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

const fallbackRows = () => SAMPLE.map((s) => ({ ...s, user_id: String(s.rank) }));

/**
 * Both boards, each as { all, me }:
 *   all — the ordered top TOP_N rows
 *   me  — the viewer's own row, with their TRUE rank even if that is far
 *         below the cut. Null when they aren't on the board at all.
 * `me` may also appear inside `all`; consumers decide how to present that.
 */
export function useBoardData(hud) {
  const [players, setPlayers] = useState({ all: null, me: null }); // all:null = loading
  const profile = (typeof window !== "undefined" && window.YGTEEV?.profile) || {};
  const sample = typeof window !== "undefined" && window.__BY_SPLASH_SAMPLE;

  useEffect(() => {
    let dead = false;
    (async () => {
      if (sample) { setPlayers({ all: fallbackRows(), me: { user_id: "me", me: true, name: "Me", rank: 7, score: 8 } }); return; }
      try {
        const api = window.YGTEEV_API;
        if (!api?.getSplashPlayers) {
          setPlayers({ all: IS_STAGING ? fallbackRows() : [], me: null });
          return;
        }
        const d = await api.getSplashPlayers();
        if (dead) return;
        let all = (d?.rows || []).map((r) => ({
          user_id: r.user_id, rank: r.rank, name: r.name || "Gardener",
          score: r.score, avatar: r.avatar, me: r.user_id === profile.id,
        }));
        if (all.length === 0 && IS_STAGING) all = fallbackRows();
        const m = d?.me;
        const me = m
          ? { user_id: m.user_id, rank: m.rank, name: "Me", score: m.score, avatar: m.avatar || profile.avatarUrl, me: true }
          : (IS_STAGING ? { user_id: "me", rank: 7, name: "Me", score: 8, avatar: profile.avatarUrl, me: true } : null);
        setPlayers({ all: all.map((r) => (r.me ? { ...r, name: "Me" } : r)), me });
      } catch {
        if (!dead) setPlayers({ all: IS_STAGING ? fallbackRows() : [], me: null });
      }
    })();
    return () => { dead = true; };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // Garden League — ALL-TIME standings from their own RPC. The weekly rows
  // in hud.league keep powering the in-garden bulletin; here they are only
  // a fallback for spotting which group is the viewer's own.
  const [groups, setGroups] = useState({ all: null, me: null });
  useEffect(() => {
    let dead = false;
    const sampleGroups = () => ({
      all: SAMPLE.map((s, i) => ({ ...s, name: ["Oak Ridge Youth", "River Church", "The Grove", "Northside", "Kings Kids"][i], user_id: String(i) })),
      me: null,
    });
    (async () => {
      if (sample) { setGroups(sampleGroups()); return; }
      try {
        const api = window.YGTEEV_API;
        if (!api?.getLeagueAllTime) {
          setGroups(IS_STAGING ? sampleGroups() : { all: [], me: null });
          return;
        }
        const rows = await api.getLeagueAllTime();
        if (dead) return;
        const myGid = window.YGTEEV?.profile?.groupId
          || (hud?.league?.rows || []).find((r) => r.mine)?.id || null;
        const ordered = (rows || []).map((r) => ({
          user_id: r.group_id, rank: r.rank, name: r.group_name,
          score: r.berries, me: !!myGid && r.group_id === myGid,
        }));
        if (!ordered.length && IS_STAGING) { setGroups(sampleGroups()); return; }
        setGroups({ all: ordered.slice(0, TOP_N), me: ordered.find((r) => r.me) || null });
      } catch {
        if (!dead) setGroups(IS_STAGING ? sampleGroups() : { all: [], me: null });
      }
    })();
    return () => { dead = true; };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return { players, groups };
}

/** Compact, non-scrolling list. Kept for any surface too short for ScrollBoard. */
export function BoardRows({ rows, tab, S }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 * S, padding: `${4 * S}px ${8 * S}px` }}>
      {rows === null && <EmptyNote S={S}>Gathering the top gardeners…</EmptyNote>}
      {Array.isArray(rows) && rows.length === 0 && (
        <EmptyNote S={S}>
          {tab === "players"
            ? "No gardeners have levelled up yet — harvest to earn gems!"
            : "No gardens on the board yet — plant rare berries!"}
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

// Header strip over the list. Only the score column is labelled — it is the
// column whose meaning isn't obvious, and the rank/name/avatar speak for
// themselves. Aligned to WoodRow's cut-out window (asset x 891..1110 of 210
// tall, i.e. right offset 40..259).
function ColumnHead({ tab, rowH, S }) {
  const k = rowH / 210;
  return (
    <div style={{ position: "relative", height: 30 * S, marginBottom: 3 * S }}>
      <div
        style={{
          // Right-aligned to the score window's outer edge rather than
          // centred on it: "RARE BERRIES" is far wider than the window, and
          // centring pushed it into the panel's rail. Growing leftwards into
          // the empty header row keeps that clearance at any size.
          position: "absolute", left: 0, right: 40 * k, top: 0,
          textAlign: "right", fontFamily: T.font, fontWeight: 800,
          fontSize: 26 * S, letterSpacing: 0.4, color: "#5f4a2a",
          textShadow: "0 1px 0 rgba(255,250,238,.7)",
          whiteSpace: "nowrap",
        }}
      >
        {SCORE_LABEL[tab]}
      </div>
    </div>
  );
}

/**
 * Full board: top 20 in a scroller, with the viewer always accounted for.
 * If they're inside the 20 their row is scrolled into view; if they're not,
 * it is pinned below the list so "where do I stand" never needs a scroll.
 */
export function ScrollBoard({ board, tab, S, visibleRows = 6.45, maxVh = null }) {
  const rows = board?.all;
  const me = board?.me;
  const rowH = 78 * S;
  const scroller = useRef(null);
  const meRow = useRef(null);
  const [atEnd, setAtEnd] = useState(false);

  const inTop = Array.isArray(rows) && rows.some((r) => r.me);
  const pxCap = rowH * visibleRows + 8 * S * Math.floor(visibleRows);
  const pinH = me && !inTop ? rowH + 31 * S : 0; // pinned row + its separator

  // bring the viewer's row into view when it's in the list but below the fold
  useEffect(() => {
    if (!inTop || !meRow.current || !scroller.current) return;
    const el = meRow.current, box = scroller.current;
    const off = el.offsetTop - box.clientHeight / 2 + el.offsetHeight / 2;
    box.scrollTop = Math.max(0, off);
  }, [inTop, tab, rows]);

  const onScroll = (e) => {
    const el = e.currentTarget;
    setAtEnd(el.scrollTop + el.clientHeight >= el.scrollHeight - 4);
  };
  useEffect(() => { // a short list isn't scrollable at all — no fade
    const el = scroller.current;
    if (el) setAtEnd(el.scrollHeight <= el.clientHeight + 4);
  }, [rows, tab]);

  if (rows === null) return <EmptyNote S={S}>Gathering the top gardeners…</EmptyNote>;
  if (Array.isArray(rows) && rows.length === 0) {
    return (
      <EmptyNote S={S}>
        {tab === "players"
          ? "No gardeners have levelled up yet — harvest to earn gems!"
          : "No gardens on the board yet — plant rare berries!"}
      </EmptyNote>
    );
  }

  return (
    <div style={{ padding: `0 ${8 * S}px` }}>
      <ColumnHead tab={tab} rowH={rowH} S={S} />
      <div style={{ position: "relative" }}>
        <div
          ref={scroller}
          onScroll={onScroll}
          style={{
            display: "flex", flexDirection: "column", gap: 8 * S,
            // 6 rows and a sliver of the 7th, so there is always a visible
            // reason to scroll rather than a list that looks complete.
            // maxVh additionally caps it against the viewport — the splash
            // shares its frame with START GAME, and on a short phone the
            // full six rows would push that button off the bottom. The
            // pinned "you" row, when there is one, comes out of the same
            // budget; without that subtraction a below-the-cut player on a
            // 667pt screen pushed START GAME just off the edge.
            maxHeight: maxVh
              ? `max(${rowH * 2.2}px, min(${pxCap}px, calc(${maxVh}vh - ${pinH}px)))`
              : pxCap,
            overflowY: "auto", overscrollBehavior: "contain",
            WebkitOverflowScrolling: "touch",
            paddingBottom: 2 * S,
          }}
        >
          {rows.map((r) => (
            <div key={r.user_id ?? r.rank} ref={r.me ? meRow : null} style={{ flexShrink: 0 }}>
              <WoodRow
                rank={r.rank} name={r.name} score={r.score} avatarUrl={r.avatar}
                tone={toneForRank(r.rank)} me={r.me} height={rowH}
              />
            </div>
          ))}
        </div>
        {!atEnd && (
          <div
            style={{
              position: "absolute", left: 0, right: 0, bottom: 0, height: 34 * S,
              pointerEvents: "none",
              background: "linear-gradient(180deg, rgba(214,190,155,0), rgba(201,171,134,.85))",
            }}
          />
        )}
      </div>

      {/* below the cut — pin their standing so it never needs hunting for */}
      {me && !inTop && (
        <div style={{ marginTop: 9 * S }}>
          <div
            style={{
              textAlign: "center", fontFamily: T.font, fontWeight: 800,
              fontSize: 17 * S, letterSpacing: 3, color: "#8a7350",
              lineHeight: 1, marginBottom: 5 * S,
            }}
          >
            •••
          </div>
          <WoodRow
            rank={me.rank} name={me.name} score={me.score} avatarUrl={me.avatar}
            tone="wood" me height={rowH}
          />
        </div>
      )}
    </div>
  );
}

/** In-game modal — the same board the title screen shows, centred over the world. */
export default function WeeklyBoardModal({ hud, onClose }) {
  const [tab, setTab] = useState("players");
  // pull fresh standings the moment the board opens — the background poll
  // runs every 60s, so without this the board can show minute-old numbers
  React.useEffect(() => { try { window.__BY_G?.refreshLeague?.(); } catch (e) {} }, []);
  const { players, groups } = useBoardData(hud);
  const board = tab === "players" ? players : groups;

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
              tabs={[
                { key: "players", label: "Players" },
                { key: "groups", label: "Garden League", weight: 1.5 },
              ]}
              active={tab}
              onChange={setTab}
              height={72 * S}
              fontSize={26 * S}
              style={{ margin: `${36 * S}px ${44 * S}px 0` }}
            />
            <ScrollBoard board={board} tab={tab} S={S} />
          </div>
        </StonePanel>
      </div>

      <style>{`
        @keyframes byBoardIn { from { opacity: 0 } to { opacity: 1 } }
      `}</style>
    </div>
  );
}
