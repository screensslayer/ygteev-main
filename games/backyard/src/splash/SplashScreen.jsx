// Backyard splash / title screen — renders OVER the live 3D garden.
// The camera holds a cinematic vantage while this is up (G.splashActive);
// START slides the menu away as the camera glides home.
//
// Layout is PROPORTIONAL: every size is expressed in mockup design units
// (the approved 768px-wide mockup) multiplied by one scale factor derived
// from the actual container width — so the composition matches the mockup
// on any device size.

import React, { useEffect, useLayoutEffect, useRef, useState } from "react";
import {
  T, StonePanel, StoneSlab, TabToggle, ParchmentButton,
} from "./ui-kit.jsx";
import { useBoardData, ScrollBoard } from "./WeeklyBoard.jsx";

export default function SplashScreen({ hud, onStart, onRequestClose, onGone }) {
  const [tab, setTab] = useState("players");
  // the board starts minimised — tapping the WEEKLY LEADERBOARD sign opens it
  const [boardOpen, setBoardOpen] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const rootRef = useRef(null);
  const [rootW, setRootW] = useState(Math.min(typeof window !== "undefined" ? window.innerWidth : 430, 560));

  useLayoutEffect(() => {
    const measure = () => {
      if (rootRef.current) setRootW(rootRef.current.clientWidth);
    };
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, []);

  // one design unit = 1px in the 768-wide mockup
  const S = rootW / 768;

  const profile = window.YGTEEV?.profile || {};
  const pulse = hud?.league?.pulse || {};

  // The overlay is transparent (live garden shows through), so body-mounted
  // game HUDs (glowlands lantern/satchel) would show through too — hide them
  // for as long as the splash is mounted.
  useEffect(() => {
    document.body.classList.add("by-splash-open");
    return () => document.body.classList.remove("by-splash-open");
  }, []);

  const { players, groups } = useBoardData(hud);

  const board = tab === "players" ? players : groups;

  const start = () => {
    if (leaving) return;
    setLeaving(true);
    onStart && onStart(); // camera starts gliding home while the menu slides away
    setTimeout(() => onGone && onGone(), 650);
  };
  const close = () => {
    if (leaving) return;
    const handled = onRequestClose && onRequestClose();
    if (!handled) start(); // browser fallback: Close enters the garden too
  };

  return (
    <div
      style={{
        position: "fixed", inset: 0, zIndex: 90,
        fontFamily: T.font,
        opacity: leaving ? 0 : 1,
        transition: "opacity .55s ease .1s",
        pointerEvents: leaving ? "none" : "auto",
      }}
    >
      {/* legibility scrim over the live scene */}
      <div
        style={{
          position: "absolute", inset: 0, pointerEvents: "none",
          background:
            "radial-gradient(ellipse 120% 100% at 50% 30%, rgba(20,26,20,.10) 0%, rgba(20,26,20,.34) 100%)",
          opacity: leaving ? 0 : 1,
          transition: "opacity .5s ease",
        }}
      />

      {/* everything that slides away */}
      <div
        ref={rootRef}
        style={{
          position: "absolute", inset: 0,
          maxWidth: 560, margin: "0 auto",
          display: "flex", flexDirection: "column", alignItems: "center",
          padding: `calc(${20 * S}px + env(safe-area-inset-top, 0px)) 0 calc(${44 * S}px + env(safe-area-inset-bottom, 0px))`,
          boxSizing: "border-box",
          transform: leaving ? "translateY(-7vh) scale(.98)" : "none",
          transition: "transform .55s cubic-bezier(.5,0,.6,1)",
        }}
      >
        {/* ------- top bar: close button + the live-player readout -------
            Gold/XP plates and the profile medallion belong to the in-game HUD;
            the title screen only carries the "who's playing right now" signal. */}
        <div style={{ position: "relative", width: "100%", minHeight: 120 * S, display: "flex", alignItems: "center", padding: `0 ${14 * S}px`, boxSizing: "border-box" }}>
          <div
            style={{
              position: "absolute", left: "50%", top: "50%", transform: "translate(-50%,-50%)",
              display: "flex", alignItems: "center", gap: 12 * S, whiteSpace: "nowrap",
            }}
          >
            <span
              style={{
                width: 20 * S, height: 20 * S, borderRadius: "50%", flexShrink: 0,
                background: "radial-gradient(circle at 34% 30%, #d6ffe4, #35d07a 62%, #168a49)",
                animation: "byLivePulse 2.6s ease-in-out infinite",
              }}
            />
            <span
              style={{
                fontFamily: T.font, fontWeight: 800, fontSize: 26 * S, color: "#f4ffe9",
                textShadow: "0 2px 5px rgba(10,25,10,.75), 0 0 14px rgba(0,0,0,.35)",
              }}
            >
              {Math.max(1, pulse.players_today || 0)} Active Players Today
            </span>
          </div>
        </div>

        {/* ------- logo ------- */}
        <img
          src="/ui/backyard-logo.png"
          alt="Backyard"
          draggable={false}
          style={{
            width: 600 * S,
            // rule of thirds: logo's visual center sits high in the upper
            // third; clamped so short screens don't starve the world band
            marginTop: "clamp(-14px, 1.6vh, 34px)",
            filter: "drop-shadow(0 6px 14px rgba(30,20,5,.45)) drop-shadow(0 0 26px rgba(255,224,150,.35))",
            userSelect: "none",
            animation: "bySplashLogo .8s cubic-bezier(.2,1.4,.4,1) both",
          }}
        />

        {/* ------- leaderboard panel (mockup: frame 46..700, slab overlaps top) ------- */}
        <div style={{ position: "relative", width: 656 * S, marginTop: "auto", paddingTop: 60 * S }}>
          {/* the sign doubles as the open/close control for the board */}
          <StoneSlab
            onClick={() => setBoardOpen((o) => !o)}
            style={{
              // wrapper has 60*S top padding (bottom-anchored layout); the
              // sign tucks into the panel's top rail like the mockup
              position: "absolute", top: 6 * S, left: "50%", transform: "translateX(-50%)",
              zIndex: 5, width: 470 * S, cursor: "pointer",
            }}
          />

          <StonePanel edge={46 * S} corner={94 * S}>
            <div style={{ display: "flex", flexDirection: "column", gap: 12 * S }}>
              {boardOpen && (
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
              )}

              {/* the same top-20 board as the in-game modal, capped against
                  the viewport so START GAME always stays on screen */}
              {boardOpen && <ScrollBoard board={board} tab={tab} S={S} maxVh={38} />}

              <ParchmentButton
                onClick={start}
                style={{ margin: `${boardOpen ? 18 * S : 46 * S}px ${16 * S}px 0` }}
              />

            </div>
          </StonePanel>
        </div>
      </div>

      <style>{`
        @keyframes byLivePulse {
          0%, 100% { opacity: .32; box-shadow: 0 0 0 0 rgba(60,220,130,.0), 0 1px 2px rgba(0,0,0,.5) }
          50%      { opacity: 1;   box-shadow: 0 0 10px 3px rgba(70,235,145,.75), 0 1px 2px rgba(0,0,0,.5) }
        }
        @keyframes bySplashLogo {
          0% { transform: translateY(-14px) scale(.82); opacity: 0 }
          60% { opacity: 1 }
          100% { transform: none; opacity: 1 }
        }
        body.by-splash-open [data-glow-hud],
        body.by-splash-open [data-glow-hud-satchel] { display: none !important; }
      `}</style>
    </div>
  );
}
