// pastor-flow.jsx — Onboarding wizard shell for YGTeeV (pastor-side)
// Router, progress bar, slide transitions, shared chrome.

const { useState, useEffect, useRef, useMemo, useCallback } = React;

// ─── design constants ───────────────────────────────────────────
const VIOLET = '#6B2BFF';
const VIOLET_DEEP = '#3D0FB8';
const PINK = '#FF3DA5';
const CYAN = '#00E0FF';
const LIME = '#B4FF3C';
const YELLOW = '#FFD60A';
const PAPER = '#FAF8FF';
const PAPER_2 = '#F0EDF8';
const INK = '#1A1330';
const INK_SOFT = 'rgba(26,19,48,0.62)';
const INK_FAINT = 'rgba(26,19,48,0.10)';

const GRAD = `linear-gradient(135deg, ${VIOLET} 0%, ${PINK} 100%)`;
const GRAD_SOFT = `linear-gradient(135deg, ${VIOLET}10 0%, ${PINK}10 100%)`;

window.YG = { VIOLET, VIOLET_DEEP, PINK, CYAN, LIME, YELLOW, PAPER, PAPER_2, INK, INK_SOFT, INK_FAINT, GRAD, GRAD_SOFT };

// ─── Wizard ordering ────────────────────────────────────────────
// 11 screens: landing → create → group → brand → 4 tours → pricing → checkout → welcome
const STEPS = [
  { id: 'landing',  kind: 'landing',  progress: null },
  { id: 'create',   kind: 'form',     progress: 0 },
  { id: 'group',    kind: 'form',     progress: 1 },
  { id: 'brand',    kind: 'form',     progress: 2 },
  { id: 'tour-1',   kind: 'tour',     progress: 'tours', tourIdx: 0 },
  { id: 'tour-2',   kind: 'tour',     progress: 'tours', tourIdx: 1 },
  { id: 'tour-3',   kind: 'tour',     progress: 'tours', tourIdx: 2 },
  { id: 'tour-4',   kind: 'tour',     progress: 'tours', tourIdx: 3 },
  { id: 'pricing',  kind: 'form',     progress: 7 },
  { id: 'checkout', kind: 'checkout', progress: null },
  { id: 'welcome',  kind: 'welcome',  progress: null },
];

window.STEPS = STEPS;

// ─── App state (mock — no real wiring) ──────────────────────────
function useAppState() {
  const [data, setData] = useState({
    firstName: 'Jordan',
    lastName: 'Riggs',
    email: 'jordan@northpoint.church',
    password: '',
    churchName: '',
    addressLine: '',
    addressCity: 'Charlotte, NC',
    meetingDay: 'Wednesday',
    meetingTime: '6:30 PM',
    groupName: '',
    description: '',
    gradient: 0,
    publicOnMap: true,
    logoFile: null,
    pricingTier: 'starter',
  });
  const set = useCallback((patch) => setData(d => ({ ...d, ...patch })), []);
  return [data, set];
}
window.useAppState = useAppState;

// ─── Progress bar (top of screen, 8 segments) ──────────────────
function ProgressBar({ step, dark }) {
  const cur = STEPS[step];
  if (!cur || cur.progress === null) return null;
  // segments: 0,1,2 = forms; 3 = tours cluster (4 dots); 4 = pricing
  // We render 8 dashes; segments fill based on step.
  const totalSegs = 8;
  let filled = 0;
  if (cur.progress === 'tours') {
    filled = 3 + (cur.tourIdx + 1); // tours take 4 segments
  } else {
    filled = cur.progress + 1;
    if (filled > 3) filled = 3 + 4 + (cur.progress - 6); // bump past tours
  }

  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, zIndex: 40,
      padding: '14px 16px 12px',
      pointerEvents: 'none',
    }}>
      <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
        {Array.from({ length: totalSegs }).map((_, i) => {
          const isOn = i < filled;
          const isTour = i >= 3 && i < 7;
          // make tour segs slightly smaller/thinner cluster look
          return (
            <div key={i} style={{
              flex: isTour ? 0.7 : 1,
              height: 4, borderRadius: 4,
              background: isOn
                ? (dark ? '#fff' : VIOLET)
                : (dark ? 'rgba(255,255,255,0.22)' : 'rgba(26,19,48,0.10)'),
              transition: 'background 0.3s, flex 0.3s',
            }}/>
          );
        })}
      </div>
    </div>
  );
}

// ─── Top-bar chrome (back arrow + skip) ────────────────────────
function TopBar({ onBack, onSkip, showSkip, dark }) {
  const c = dark ? '#fff' : INK;
  const soft = dark ? 'rgba(255,255,255,0.65)' : INK_SOFT;
  return (
    <div style={{
      position: 'absolute', top: 24, left: 0, right: 0, zIndex: 35,
      padding: '0 12px',
      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    }}>
      <button onClick={onBack}
        disabled={!onBack}
        style={{
          width: 36, height: 36, borderRadius: 18,
          background: dark ? 'rgba(255,255,255,0.12)' : 'rgba(26,19,48,0.05)',
          border: 'none', cursor: onBack ? 'pointer' : 'default',
          opacity: onBack ? 1 : 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: c,
        }}>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
          <path d="M15 18l-6-6 6-6" stroke="currentColor" strokeWidth="2.5"
            strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </button>
      {showSkip ? (
        <button onClick={onSkip} style={{
          padding: '6px 12px', borderRadius: 999,
          background: 'transparent', border: 'none',
          color: soft, fontSize: 13, fontWeight: 600,
          fontFamily: 'var(--font-body)', cursor: 'pointer',
          letterSpacing: -0.1,
        }}>
          Skip tour →
        </button>
      ) : <div/>}
    </div>
  );
}

// ─── Big primary CTA ────────────────────────────────────────────
function CTA({ children, onClick, full, secondary, dark, disabled }) {
  if (secondary) {
    return (
      <button onClick={!disabled ? onClick : undefined} style={{
        width: full ? '100%' : 'auto',
        padding: '15px 24px',
        background: dark ? 'rgba(255,255,255,0.08)' : '#fff',
        border: dark ? '1px solid rgba(255,255,255,0.22)' : '1px solid rgba(26,19,48,0.12)',
        borderRadius: 999,
        color: dark ? '#fff' : INK,
        fontFamily: 'var(--font-display)', fontWeight: 700,
        fontSize: 16, letterSpacing: -0.2,
        cursor: 'pointer',
      }}>
        {children}
      </button>
    );
  }
  return (
    <button onClick={!disabled ? onClick : undefined} style={{
      width: full ? '100%' : 'auto',
      padding: '16px 26px',
      background: disabled ? 'rgba(26,19,48,0.12)' : GRAD,
      border: 'none', borderRadius: 999,
      color: '#fff',
      fontFamily: 'var(--font-display)', fontWeight: 800,
      fontSize: 16, letterSpacing: -0.2,
      boxShadow: disabled ? 'none'
        : '0 1px 0 rgba(255,255,255,0.3) inset, 0 -2px 0 rgba(0,0,0,0.18) inset, 0 10px 26px rgba(107,43,255,0.34)',
      cursor: disabled ? 'default' : 'pointer',
      transition: 'transform 0.08s ease, box-shadow 0.15s',
    }}
    onMouseDown={(e) => !disabled && (e.currentTarget.style.transform = 'translateY(1px) scale(0.98)')}
    onMouseUp={(e) => !disabled && (e.currentTarget.style.transform = '')}
    onMouseLeave={(e) => !disabled && (e.currentTarget.style.transform = '')}
    >
      {children}
    </button>
  );
}
window.CTA = CTA;
window.ProgressBar = ProgressBar;
window.TopBar = TopBar;

// ─── Trust footer ──────────────────────────────────────────────
function TrustFooter({ dark }) {
  const c = dark ? 'rgba(255,255,255,0.55)' : INK_SOFT;
  return (
    <div style={{
      display: 'flex', justifyContent: 'center', alignItems: 'center',
      gap: 14, flexWrap: 'wrap',
      padding: '20px 16px 22px',
      fontSize: 11.5, color: c, fontWeight: 500,
      letterSpacing: -0.1, textAlign: 'center',
    }}>
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
        <span style={{ width: 6, height: 6, borderRadius: 3, background: LIME }}/>
        Built by people who run youth groups
      </span>
      <span style={{ opacity: 0.4 }}>·</span>
      <span>Your data is yours</span>
      <span style={{ opacity: 0.4 }}>·</span>
      <a style={{ color: 'inherit', textDecoration: 'underline' }}>Privacy</a>
    </div>
  );
}
window.TrustFooter = TrustFooter;

// ─── Slide-card surface ────────────────────────────────────────
// On mobile, fills the wizard column.
// On desktop, centered card with paper-2 background around it.
function Surface({ children, dark, bg, scroll, className = '' }) {
  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: bg || (dark ? INK : PAPER),
      color: dark ? '#fff' : INK,
      overflow: scroll ? 'auto' : 'hidden',
    }} className={className}>
      {children}
    </div>
  );
}
window.Surface = Surface;

// ─── Wizard root ───────────────────────────────────────────────
function PastorOnboarding() {
  const [step, setStep] = useState(0);
  const [direction, setDirection] = useState('fwd'); // for slide direction
  const [data, set] = useAppState();

  const go = useCallback((nextIdx) => {
    setDirection(nextIdx >= step ? 'fwd' : 'back');
    setStep(nextIdx);
    // scroll wizard to top
    requestAnimationFrame(() => {
      const surf = document.querySelector('[data-active-surface] .scrollable');
      if (surf) surf.scrollTop = 0;
    });
  }, [step]);

  const next = useCallback(() => go(Math.min(STEPS.length - 1, step + 1)), [go, step]);
  const back = useCallback(() => go(Math.max(0, step - 1)), [go, step]);

  // Persist step in URL fragment for refresh
  useEffect(() => {
    const h = window.location.hash;
    const match = h.match(/step=(\d+)/);
    if (match) {
      const n = parseInt(match[1], 10);
      if (!isNaN(n) && n >= 0 && n < STEPS.length) setStep(n);
    }
  }, []);
  useEffect(() => {
    history.replaceState(null, '', `#step=${step}`);
  }, [step]);

  const cur = STEPS[step];
  const dark = cur.kind === 'tour' && cur.tourIdx % 2 === 1;
  // tour 0 (small groups) = light, tour 1 (chat) = dark,
  // tour 2 (events) = light, tour 3 (bible) = dark
  const showSkip = cur.kind === 'tour';

  return (
    <div style={{
      position: 'fixed', inset: 0,
      background: '#0a091f',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      overflow: 'hidden',
      fontFamily: 'var(--font-body)',
    }}>
      {/* Desktop ambient gradient backdrop */}
      <div style={{
        position: 'absolute', inset: 0,
        background: `radial-gradient(60% 50% at 20% 10%, ${VIOLET}30 0%, transparent 50%), radial-gradient(50% 40% at 80% 90%, ${PINK}25 0%, transparent 60%), #0a091f`,
        pointerEvents: 'none',
      }}/>

      {/* Wizard column — full-screen on mobile, card on desktop */}
      <div className="wizard-col" style={{
        position: 'relative',
        width: '100%',
        maxWidth: 'min(100vw, 480px)',
        height: '100dvh',
        maxHeight: '100dvh',
        overflow: 'hidden',
        background: PAPER,
        boxShadow: '0 20px 80px rgba(0,0,0,0.45)',
      }}>

        {/* Layered slides — only render current + previous for transitions */}
        {STEPS.map((s, i) => {
          const active = i === step;
          if (Math.abs(i - step) > 1 && !active) return null;
          const off = i === step ? 0 : (i < step ? '-100%' : '100%');
          return (
            <div key={s.id}
              data-active-surface={active ? '' : undefined}
              style={{
                position: 'absolute', inset: 0,
                transform: `translateX(${off})`,
                transition: 'transform 0.42s cubic-bezier(0.32,0.72,0,1)',
                willChange: 'transform',
              }}>
              <Screen step={i} data={data} set={set} go={go} next={next} back={back}/>
            </div>
          );
        })}

        {/* Chrome — over everything, follows active step's theme */}
        <ProgressBar step={step} dark={dark}/>
        <TopBar
          onBack={step > 0 && step < STEPS.length - 1 ? back : null}
          onSkip={() => go(8 /* jump to pricing */)}
          showSkip={showSkip}
          dark={dark}/>
      </div>

      {/* Desktop edge hints */}
      <div className="desktop-hint" style={{
        position: 'absolute', top: 24, left: 24, color: 'rgba(255,255,255,0.5)',
        fontSize: 11, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase',
        fontFamily: 'var(--font-body)',
        pointerEvents: 'none',
      }}>
        YGTeeV · Pastor Onboarding
      </div>
      <div className="desktop-hint" style={{
        position: 'absolute', bottom: 24, right: 24, color: 'rgba(255,255,255,0.4)',
        fontSize: 11, fontWeight: 500, fontFamily: 'var(--font-mono)',
        pointerEvents: 'none',
      }}>
        Step {step + 1} / {STEPS.length}
      </div>

      <style>{`
        @media (max-width: 600px) {
          .desktop-hint { display: none; }
          .wizard-col { max-width: 100vw !important; box-shadow: none !important; }
        }
        @keyframes pop-in {
          0% { transform: scale(0.6) translateY(20px); opacity: 0; }
          70% { transform: scale(1.08) translateY(-2px); opacity: 1; }
          100% { transform: scale(1) translateY(0); opacity: 1; }
        }
        @keyframes pulse-soft {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.03); }
        }
        @keyframes pin-drop {
          0% { transform: translate(-50%, -160%) scale(0.6); opacity: 0; }
          60% { transform: translate(-50%, -100%) scale(1.05); opacity: 1; }
          80% { transform: translate(-50%, -95%) scale(0.97); }
          100% { transform: translate(-50%, -100%) scale(1); }
        }
        @keyframes confetti-fall {
          0% { transform: translateY(-20px) rotate(0deg); opacity: 1; }
          100% { transform: translateY(110vh) rotate(720deg); opacity: 0; }
        }
        @keyframes toast-in {
          0% { transform: translateY(-30px); opacity: 0; }
          60% { transform: translateY(4px); opacity: 1; }
          100% { transform: translateY(0); }
        }
        @keyframes shimmer {
          0% { background-position: -200px 0; }
          100% { background-position: 200px 0; }
        }
        @keyframes float-y {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-6px); }
        }
        .scrollable { overflow-y: auto; height: 100%; }
        .scrollable::-webkit-scrollbar { width: 0; }
      `}</style>
    </div>
  );
}

// ─── Screen dispatch ───────────────────────────────────────────
const SCREEN_MAP = {
  'landing':  'ScreenLanding',
  'create':   'ScreenCreate',
  'group':    'ScreenGroup',
  'brand':    'ScreenBrand',
  'tour-1':   'ScreenTourSmallGroups',
  'tour-2':   'ScreenTourSafeChat',
  'tour-3':   'ScreenTourEvents',
  'tour-4':   'ScreenTourBible',
  'pricing':  'ScreenPricing',
  'checkout': 'ScreenCheckout',
  'welcome':  'ScreenWelcome',
};
function Screen({ step, data, set, go, next, back }) {
  const cur = STEPS[step];
  const Comp = window[SCREEN_MAP[cur.id]];
  if (!Comp) {
    return <div style={{ padding: 40, color: '#fff' }}>
      Missing screen component: {SCREEN_MAP[cur.id]}
    </div>;
  }
  return <Comp data={data} set={set} go={go} next={next} back={back} step={step}/>;
}

window.PastorOnboarding = PastorOnboarding;
