// pastor-screens-2.jsx — Tour screens (4-7), pricing, checkout, welcome.

const Y2 = window.YG;
const { CTA: CTA2, TrustFooter: TF2, MapPin: MP2 } = window;

// ════════════════════════════════════════════════════════════════
// Shared TOUR layout
// ════════════════════════════════════════════════════════════════
function Tour({ dark, eyebrow, title, body, hero, accent, onContinue }) {
  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: dark
        ? `radial-gradient(80% 60% at 30% 10%, ${Y2.VIOLET_DEEP} 0%, ${Y2.INK} 60%, #0A0712 100%)`
        : Y2.PAPER,
      color: dark ? '#fff' : Y2.INK,
      overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Hero region (top 55%) */}
      <div style={{
        flex: '1 1 55%', position: 'relative',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        paddingTop: 70, paddingBottom: 12,
      }}>
        {hero}
      </div>

      {/* Copy region (bottom 45%) */}
      <div style={{
        padding: '20px 22px 24px',
        position: 'relative',
      }}>
        <div style={{
          fontSize: 11, fontWeight: 800,
          color: accent || Y2.PINK,
          letterSpacing: 1.5, textTransform: 'uppercase',
          fontFamily: 'var(--font-display)', marginBottom: 8,
        }}>{eyebrow}</div>
        <h2 style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 28, letterSpacing: -1.1, lineHeight: 1.05,
          margin: '0 0 10px', textWrap: 'balance',
        }}>{title}</h2>
        <p style={{
          fontSize: 14.5, lineHeight: 1.45,
          color: dark ? 'rgba(255,255,255,0.75)' : Y2.INK_SOFT,
          margin: '0 0 22px', textWrap: 'balance', maxWidth: 360,
        }}>{body}</p>
        <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
          <CTA2 onClick={onContinue}>Got it →</CTA2>
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 4 — TOUR: SMALL GROUPS  (light)
// ════════════════════════════════════════════════════════════════
function ScreenTourSmallGroups({ next }) {
  return (
    <Tour dark={false}
      eyebrow="Tour · 1 of 4"
      title="Split your group however you split your group."
      body="Tuesday small group, Sunday class, worship team — make as many as you need and assign leaders. Switch in one tap."
      accent={Y2.VIOLET}
      onContinue={next}
      hero={
        <div style={{
          position: 'relative', width: 320, height: 360,
        }}>
          {/* stack of group cards */}
          {[
            { name: 'Wednesday Night', leader: 'Pastor Jordan', members: 42, color: Y2.VIOLET, top: 0, x: 0, rotate: -4 },
            { name: '9th Grade Guys', leader: 'Marcus T.', members: 8, color: Y2.PINK, top: 70, x: 18, rotate: 3 },
            { name: 'Worship Team', leader: 'Ana K.', members: 6, color: Y2.CYAN, top: 140, x: -12, rotate: -6 },
            { name: 'Sr. High Girls', leader: 'Beth L.', members: 11, color: Y2.LIME, top: 210, x: 14, rotate: 4 },
          ].map((c, i) => (
            <div key={i} style={{
              position: 'absolute', top: c.top, left: 30 + c.x,
              width: 260, padding: 14,
              borderRadius: 18, background: '#fff',
              border: `1px solid ${Y2.INK_FAINT}`,
              boxShadow: '0 18px 36px rgba(26,19,48,0.14)',
              transform: `rotate(${c.rotate}deg)`,
              zIndex: 10 - i,
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{
                  width: 36, height: 36, borderRadius: 10,
                  background: `linear-gradient(135deg, ${c.color}, ${Y2.PINK}80)`,
                  color: '#fff', fontFamily: 'var(--font-display)', fontWeight: 900,
                  fontSize: 14, display: 'flex', alignItems: 'center', justifyContent: 'center',
                  boxShadow: 'inset 0 -2px 4px rgba(0,0,0,0.18)',
                }}>{c.name.split(' ').map(w => w[0]).slice(0, 2).join('')}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800,
                    fontSize: 13.5, letterSpacing: -0.2 }}>{c.name}</div>
                  <div style={{ fontSize: 11, color: Y2.INK_SOFT, marginTop: 1 }}>
                    Led by {c.leader}
                  </div>
                </div>
                <div style={{ display: 'flex', marginRight: 2 }}>
                  {[0, 1, 2].map(k => (
                    <div key={k} style={{
                      width: 18, height: 18, borderRadius: 9,
                      background: ['#FFD9B0', '#C8B5FF', '#B4FF3C'][k],
                      border: '1.5px solid #fff', marginLeft: k ? -6 : 0,
                    }}/>
                  ))}
                </div>
                <div style={{
                  fontSize: 10, color: Y2.INK_SOFT, fontFamily: 'var(--font-mono)',
                }}>+{c.members - 3}</div>
              </div>
              {/* leader badge */}
              <div style={{
                position: 'absolute', top: -8, right: -8,
                background: c.color, color: i === 1 || i === 3 ? Y2.INK : '#fff',
                borderRadius: 999, padding: '3px 9px',
                fontSize: 9, fontWeight: 900, fontFamily: 'var(--font-display)',
                letterSpacing: 0.4, textTransform: 'uppercase',
                border: '2px solid #fff',
              }}>Leader</div>
            </div>
          ))}
        </div>
      }/>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 5 — TOUR: SAFE CHAT (dark, animated)
// ════════════════════════════════════════════════════════════════
function ScreenTourSafeChat({ next }) {
  return (
    <Tour dark
      eyebrow="Tour · 2 of 4"
      title="Every message moderated. You get the receipts."
      body="We use AI to flag bullying, sexual content, and self-harm — and the alert lands in your inbox the moment it happens."
      accent={Y2.PINK}
      onContinue={next}
      hero={
        <div style={{
          width: 260, height: 440, background: '#0a091f',
          borderRadius: 36, padding: 8, position: 'relative',
          boxShadow: '0 30px 80px rgba(0,0,0,0.6), inset 0 0 0 1px rgba(255,255,255,0.08)',
        }}>
          <div style={{ position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)',
            width: 90, height: 22, background: '#000', borderRadius: 14, zIndex: 4 }}/>
          <div style={{
            width: '100%', height: '100%', borderRadius: 30,
            background: '#0F0E2E', overflow: 'hidden', position: 'relative',
            padding: '38px 12px 12px', color: '#fff',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between',
              fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 13 }}>
              <span>9th Grade Guys</span>
              <span style={{ fontSize: 9, fontFamily: 'var(--font-mono)', opacity: 0.6 }}>11 ONLINE</span>
            </div>

            <div style={{ marginTop: 16, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <Msg name="Tyler" color={Y2.CYAN} text="who's coming Wed?"/>
              <Msg name="Alex" color={Y2.LIME} text="me + Jake"/>
              <div style={{
                background: 'rgba(255,255,255,0.04)', borderRadius: 12,
                padding: '8px 10px',
                border: '1px dashed rgba(255,255,255,0.15)',
                color: 'rgba(255,255,255,0.45)', fontSize: 11, fontStyle: 'italic',
                display: 'flex', alignItems: 'center', gap: 8,
              }}>
                <span style={{ fontSize: 14 }}>🔒</span>
                <span>1 message hidden — your review →</span>
              </div>
              <Msg name="Jordan" color={Y2.YELLOW} text="bring \$5 for pizza"/>
            </div>

            {/* alert toast slides in */}
            <div style={{
              position: 'absolute', top: 44, left: 8, right: 8,
              background: 'rgba(255,255,255,0.97)',
              color: Y2.INK, borderRadius: 14,
              padding: '10px 12px',
              boxShadow: '0 12px 30px rgba(255,61,165,0.4)',
              border: `1px solid ${Y2.PINK}40`,
              animation: 'toast-in 0.6s ease-out 0.6s both, pulse-soft 2.4s ease-in-out 1.5s infinite',
              display: 'flex', alignItems: 'center', gap: 10,
            }}>
              <div style={{
                width: 30, height: 30, borderRadius: 8,
                background: `linear-gradient(135deg, ${Y2.PINK}, ${Y2.VIOLET})`,
                color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 14, fontWeight: 900,
              }}>⚠</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 10.5, fontWeight: 900, fontFamily: 'var(--font-display)',
                  letterSpacing: 0.3, textTransform: 'uppercase', color: Y2.PINK }}>
                  Flagged · Bullying
                </div>
                <div style={{ fontSize: 11, marginTop: 1, lineHeight: 1.25, fontWeight: 600 }}>
                  Tap to review the hidden message.
                </div>
              </div>
            </div>
          </div>
        </div>
      }/>
  );
}

function Msg({ name, color, text }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
      <div style={{
        width: 26, height: 26, borderRadius: 13,
        background: color, color: Y2.INK,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: 'var(--font-display)', fontWeight: 900, fontSize: 11,
        flexShrink: 0,
      }}>{name[0]}</div>
      <div style={{
        background: 'rgba(255,255,255,0.08)', borderRadius: 12,
        padding: '6px 10px', flex: 1,
      }}>
        <div style={{ fontSize: 9.5, fontWeight: 700, opacity: 0.6 }}>{name}</div>
        <div style={{ fontSize: 12, marginTop: 1 }}>{text}</div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 6 — TOUR: EVENTS  (light)
// ════════════════════════════════════════════════════════════════
function ScreenTourEvents({ next }) {
  return (
    <Tour dark={false}
      eyebrow="Tour · 3 of 4"
      title="Run events your students brag about."
      body="Private member-only events, or public ones your students can invite friends to. RSVPs and photos all in one place."
      accent={Y2.VIOLET}
      onContinue={next}
      hero={
        <div style={{
          width: 340, position: 'relative',
          display: 'flex', gap: 12, alignItems: 'flex-start',
        }}>
          {/* PRIVATE event card */}
          <div style={{
            flex: 1, background: '#fff', borderRadius: 20,
            border: `1px solid ${Y2.INK_FAINT}`,
            boxShadow: '0 18px 36px rgba(26,19,48,0.10)',
            overflow: 'hidden', transform: 'rotate(-3deg)',
          }}>
            <div style={{
              height: 90, background: `linear-gradient(135deg, ${Y2.VIOLET}, ${Y2.VIOLET_DEEP})`,
              position: 'relative', padding: 12,
            }}>
              <div style={{
                display: 'inline-flex', alignItems: 'center', gap: 4,
                padding: '3px 8px', borderRadius: 999,
                background: 'rgba(0,0,0,0.3)', color: '#fff',
                fontSize: 9, fontWeight: 900, fontFamily: 'var(--font-display)',
                letterSpacing: 0.3, textTransform: 'uppercase',
              }}>
                <span>🔒</span>Members only
              </div>
              <div style={{
                position: 'absolute', bottom: 8, right: 10, color: '#fff',
                fontSize: 9.5, fontWeight: 800, fontFamily: 'var(--font-mono)',
                letterSpacing: 0.5, textTransform: 'uppercase', opacity: 0.85,
              }}>Fri · 7 PM</div>
            </div>
            <div style={{ padding: 12 }}>
              <div style={{
                fontFamily: 'var(--font-display)', fontWeight: 900,
                fontSize: 16, letterSpacing: -0.4, lineHeight: 1.1,
              }}>Fall Retreat</div>
              <div style={{ fontSize: 11, color: Y2.INK_SOFT, marginTop: 4, lineHeight: 1.3 }}>
                Permission slip due Fri
              </div>
              <div style={{
                display: 'flex', alignItems: 'center', gap: 4, marginTop: 10,
              }}>
                {[Y2.PINK, Y2.CYAN, Y2.LIME, Y2.YELLOW].map((c, k) => (
                  <div key={k} style={{
                    width: 18, height: 18, borderRadius: 9, background: c,
                    border: '1.5px solid #fff', marginLeft: k ? -6 : 0,
                  }}/>
                ))}
                <div style={{ fontSize: 10, color: Y2.INK_SOFT, marginLeft: 4, fontFamily: 'var(--font-mono)' }}>
                  38 RSVP'd
                </div>
              </div>
            </div>
          </div>

          {/* PUBLIC event card */}
          <div style={{
            flex: 1, background: '#fff', borderRadius: 20,
            border: `1px solid ${Y2.INK_FAINT}`,
            boxShadow: '0 18px 36px rgba(26,19,48,0.10)',
            overflow: 'hidden', transform: 'rotate(3deg) translateY(20px)',
          }}>
            <div style={{
              height: 90, background: `linear-gradient(135deg, ${Y2.LIME}, ${Y2.CYAN})`,
              position: 'relative', padding: 12,
            }}>
              <div style={{
                display: 'inline-flex', alignItems: 'center', gap: 4,
                padding: '3px 8px', borderRadius: 999,
                background: 'rgba(255,255,255,0.85)', color: Y2.INK,
                fontSize: 9, fontWeight: 900, fontFamily: 'var(--font-display)',
                letterSpacing: 0.3, textTransform: 'uppercase',
              }}>
                <span>📍</span>On the map
              </div>
              <div style={{
                position: 'absolute', bottom: 8, right: 10, color: Y2.INK,
                fontSize: 9.5, fontWeight: 800, fontFamily: 'var(--font-mono)',
                letterSpacing: 0.5, textTransform: 'uppercase',
              }}>Sat · 6 PM</div>
            </div>
            <div style={{ padding: 12 }}>
              <div style={{
                fontFamily: 'var(--font-display)', fontWeight: 900,
                fontSize: 16, letterSpacing: -0.4, lineHeight: 1.1,
              }}>Pizza & Worship</div>
              <div style={{ fontSize: 11, color: Y2.INK_SOFT, marginTop: 4, lineHeight: 1.3 }}>
                Open to friends — bring one
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 10 }}>
                {[Y2.VIOLET, Y2.PINK, Y2.YELLOW].map((c, k) => (
                  <div key={k} style={{
                    width: 18, height: 18, borderRadius: 9, background: c,
                    border: '1.5px solid #fff', marginLeft: k ? -6 : 0,
                  }}/>
                ))}
                <div style={{ fontSize: 10, color: Y2.INK_SOFT, marginLeft: 4, fontFamily: 'var(--font-mono)' }}>
                  +12 new
                </div>
              </div>
            </div>
          </div>
        </div>
      }/>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 7 — TOUR: BIBLE PLANS + GARDEN (dark)
// ════════════════════════════════════════════════════════════════
function ScreenTourBible({ next }) {
  return (
    <Tour dark
      eyebrow="Tour · 4 of 4"
      title="Every kid in your group unlocks Pro. Free."
      body="While you're a paying pastor, your students get every Bible plan, the pixel garden, streaks, and XP rewards — at no cost to them."
      accent={Y2.LIME}
      onContinue={next}
      hero={
        <div style={{
          width: 260, height: 440, background: '#0a091f',
          borderRadius: 36, padding: 8, position: 'relative',
          boxShadow: '0 30px 80px rgba(107,43,255,0.5), inset 0 0 0 1px rgba(255,255,255,0.08)',
        }}>
          <div style={{ position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)',
            width: 90, height: 22, background: '#000', borderRadius: 14, zIndex: 4 }}/>
          <div style={{
            width: '100%', height: '100%', borderRadius: 30,
            background: '#FAF8FF', overflow: 'hidden', position: 'relative',
            padding: '38px 12px 12px',
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: 900,
                fontSize: 14, color: Y2.INK, letterSpacing: -0.3 }}>
                Your plans
              </div>
              <div style={{
                background: Y2.YELLOW, borderRadius: 999, padding: '3px 8px',
                fontSize: 10, fontWeight: 900, color: Y2.INK,
                fontFamily: 'var(--font-display)', letterSpacing: 0.4,
              }}>🔥 14</div>
            </div>

            {/* Hero plan card */}
            <div style={{
              marginTop: 12, padding: 12, borderRadius: 14,
              background: `linear-gradient(135deg, ${Y2.VIOLET} 0%, ${Y2.PINK} 100%)`,
              color: '#fff', position: 'relative', overflow: 'hidden',
              boxShadow: '0 8px 22px rgba(107,43,255,0.35)',
            }}>
              <div style={{ fontSize: 9, fontWeight: 800, opacity: 0.85, letterSpacing: 0.4,
                textTransform: 'uppercase', fontFamily: 'var(--font-display)' }}>
                Day 14 of 30 · Romans
              </div>
              <div style={{ fontFamily: 'var(--font-display)', fontWeight: 900,
                fontSize: 18, letterSpacing: -0.5, marginTop: 4, lineHeight: 1.05 }}>
                "Hope does not<br/>put us to shame."
              </div>
              <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
                <Chip>+50 XP</Chip>
                <Chip>+1 💧</Chip>
              </div>
            </div>

            {/* Day grid */}
            <div style={{ marginTop: 10, display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4 }}>
              {Array.from({ length: 21 }).map((_, i) => {
                const done = i < 14;
                const today = i === 13;
                return (
                  <div key={i} style={{
                    aspectRatio: '1', borderRadius: 6,
                    background: today ? Y2.PINK : done ? Y2.VIOLET : '#fff',
                    border: today ? 'none' : `1px solid ${Y2.INK_FAINT}`,
                    color: done ? '#fff' : Y2.INK_SOFT,
                    fontSize: 9, fontWeight: 800,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontFamily: 'var(--font-display)',
                  }}>{done ? '✓' : i + 1}</div>
                );
              })}
            </div>

            {/* Garden strip */}
            <div style={{
              marginTop: 10, height: 90, borderRadius: 12,
              background: `linear-gradient(180deg, #A0E5FF, #C8B5FF)`,
              position: 'relative', overflow: 'hidden',
            }}>
              <div style={{ position: 'absolute', top: 6, right: 8, width: 14, height: 14,
                borderRadius: 7, background: Y2.YELLOW, boxShadow: `0 0 8px ${Y2.YELLOW}` }}/>
              <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 30,
                background: 'linear-gradient(180deg, #4CC65A, #2B8A3E)' }}/>
              {[
                { x: 16, w: 18, h: 28, color: '#1F7A2B' },
                { x: 50, w: 22, h: 32, color: '#2B8A3E' },
                { x: 96, w: 14, h: 18, color: '#4CC65A' },
                { x: 130, w: 20, h: 28, color: '#1F7A2B' },
                { x: 170, w: 16, h: 22, color: '#2B8A3E' },
              ].map((t, i) => (
                <React.Fragment key={i}>
                  <div style={{ position: 'absolute', bottom: 22, left: t.x,
                    width: t.w, height: t.h, background: t.color,
                    borderRadius: t.w / 2 }}/>
                  <div style={{ position: 'absolute', bottom: 16, left: t.x + (t.w - 4) / 2,
                    width: 4, height: 8, background: '#6B3F1A' }}/>
                </React.Fragment>
              ))}
            </div>
          </div>
        </div>
      }/>
  );
}

function Chip({ children }) {
  return (
    <span style={{
      padding: '2px 7px', borderRadius: 999,
      background: 'rgba(255,255,255,0.22)',
      fontSize: 9, fontWeight: 800,
      fontFamily: 'var(--font-display)', letterSpacing: 0.3,
    }}>{children}</span>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 8 — PRICING (interactive slider)
// ════════════════════════════════════════════════════════════════
const TIERS = [
  { ceiling: 19,  range: '1—19',     name: 'Starter',     price: 29  },
  { ceiling: 49,  range: '20—49',    name: 'Growing',     price: 59  },
  { ceiling: 99,  range: '50—99',    name: 'Established', price: 99  },
  { ceiling: 149, range: '100—149',  name: 'Big',         price: 129 },
  { ceiling: 199, range: '150—199',  name: 'Bigger',      price: 159 },
  { ceiling: 200, range: '200+',     name: 'Mega',        price: 189 },
];
window.TIERS = TIERS;

function ScreenPricing({ next, data, set }) {
  const idx = data.pricingTierIdx ?? 0;
  const tier = TIERS[idx];
  const denominator = idx === 5 ? 200 : tier.ceiling;
  const perStudent = (tier.price / denominator).toFixed(2);

  const trialEnd = uM(() => {
    const d = new Date();
    d.setDate(d.getDate() + 14);
    return d.toLocaleDateString('en-US', { month: 'long', day: 'numeric' });
  }, []);

  const trackRef = uR(null);
  const [dragging, setDragging] = uS(false);

  const setFromClientX = (clientX) => {
    const el = trackRef.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    const x = Math.max(0, Math.min(r.width, clientX - r.left));
    const ratio = x / r.width;
    const nextIdx = Math.round(ratio * (TIERS.length - 1));
    if (nextIdx !== idx) set({ pricingTierIdx: nextIdx });
  };

  const onTrackDown = (e) => {
    setDragging(true);
    setFromClientX(e.clientX);
    e.preventDefault();
  };
  uE(() => {
    if (!dragging) return;
    const onMove = (e) => setFromClientX(e.clientX);
    const onUp = () => setDragging(false);
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    return () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
  }, [dragging, idx]);

  const thumbPct = (idx / (TIERS.length - 1)) * 100;

  return (
    <div className="scrollable" style={{ paddingTop: 60, paddingBottom: 16 }}>
      <div style={{ padding: '0 20px' }}>
        <Pill2 color={Y2.VIOLET}>Step 8 of 8</Pill2>
        <h2 style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 30, letterSpacing: -1.2, lineHeight: 1.05,
          margin: '10px 0 8px',
        }}>Pricing that grows with your group.</h2>
        <p style={{ fontSize: 14.5, color: Y2.INK_SOFT, margin: 0, lineHeight: 1.4 }}>
          Pay for the size you actually have. The bigger your group, the less you pay per student.
        </p>
      </div>

      {/* ── PRICE CARD ─────────────────────────────────── */}
      <div style={{
        margin: '20px 16px 14px', padding: 20, borderRadius: 22,
        background: `linear-gradient(160deg, ${Y2.VIOLET_DEEP} 0%, ${Y2.VIOLET} 60%, ${Y2.PINK} 130%)`,
        color: '#fff', position: 'relative', overflow: 'hidden',
        boxShadow: '0 18px 40px rgba(107,43,255,0.4)',
      }}>
        <div style={{
          position: 'absolute', top: 14, right: 14,
          background: Y2.YELLOW, color: Y2.INK,
          padding: '4px 10px', borderRadius: 999,
          fontSize: 10, fontWeight: 900,
          fontFamily: 'var(--font-display)', letterSpacing: 0.4, textTransform: 'uppercase',
        }}>{tier.name}</div>

        <div style={{
          fontSize: 11, fontWeight: 800, opacity: 0.85,
          letterSpacing: 1.2, textTransform: 'uppercase',
          fontFamily: 'var(--font-display)',
        }}>For {tier.range} active students</div>

        <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 8 }}>
          <span key={tier.price} style={{
            fontFamily: 'var(--font-display)', fontWeight: 900,
            fontSize: 56, letterSpacing: -2, lineHeight: 1,
            animation: 'pop-in 0.4s cubic-bezier(0.32,1.6,0.64,1) both',
            display: 'inline-block',
          }}>${tier.price}</span>
          <span style={{ fontSize: 16, opacity: 0.75, fontWeight: 600 }}>/mo</span>
        </div>

        <div style={{ fontSize: 12.5, opacity: 0.8, marginTop: 6, fontFamily: 'var(--font-mono)' }}>
          ≈ ${perStudent} per active student at this tier
        </div>

        <div style={{
          marginTop: 14, padding: '10px 12px', borderRadius: 12,
          background: 'rgba(255,255,255,0.14)',
          border: '1px solid rgba(255,255,255,0.2)',
          fontSize: 12, lineHeight: 1.4, opacity: 0.92,
        }}>
          <b>Active</b> = a student who's opened the app in the last 90 days.
          Inactive students don't count toward your bill.
        </div>
      </div>

      {/* ── SLIDER ─────────────────────────────────────── */}
      <div style={{ margin: '4px 16px 20px', padding: '6px 6px 4px' }}>
        {/* thumb label */}
        <div style={{ position: 'relative', height: 30, marginBottom: 8 }}>
          <div style={{
            position: 'absolute', left: `${thumbPct}%`,
            transform: 'translateX(-50%)',
            background: Y2.INK, color: '#fff',
            padding: '6px 12px', borderRadius: 10,
            fontFamily: 'var(--font-display)', fontWeight: 800,
            fontSize: 13, letterSpacing: -0.2, whiteSpace: 'nowrap',
            boxShadow: '0 6px 16px rgba(26,19,48,0.3)',
            transition: 'left 0.18s cubic-bezier(.2,.7,.3,1.4)',
          }}>
            ≈ {idx === 5 ? '200+' : tier.ceiling} active students
            <div style={{
              position: 'absolute', bottom: -4, left: '50%',
              transform: 'translateX(-50%) rotate(45deg)',
              width: 8, height: 8, background: Y2.INK,
            }}/>
          </div>
        </div>

        {/* track */}
        <div ref={trackRef} onPointerDown={onTrackDown}
          style={{
            position: 'relative', height: 36, cursor: 'pointer',
            touchAction: 'none',
            display: 'flex', alignItems: 'center',
          }}>
          {/* track bar */}
          <div style={{
            position: 'absolute', left: 0, right: 0, height: 8,
            borderRadius: 4,
            background: 'rgba(26,19,48,0.10)',
          }}/>
          {/* filled portion */}
          <div style={{
            position: 'absolute', left: 0, height: 8,
            width: `${thumbPct}%`,
            borderRadius: 4,
            background: Y2.GRAD,
            transition: dragging ? 'none' : 'width 0.18s cubic-bezier(.2,.7,.3,1.4)',
          }}/>
          {/* ticks */}
          {TIERS.map((t, i) => {
            const left = (i / (TIERS.length - 1)) * 100;
            const on = i <= idx;
            return (
              <div key={i} style={{
                position: 'absolute', left: `${left}%`,
                transform: 'translateX(-50%)',
                width: 10, height: 10, borderRadius: 5,
                background: on ? '#fff' : 'rgba(26,19,48,0.18)',
                border: on ? `2px solid ${Y2.VIOLET}` : 'none',
                boxShadow: on ? '0 2px 4px rgba(107,43,255,0.4)' : 'none',
                pointerEvents: 'none',
              }}/>
            );
          })}
          {/* thumb */}
          <div style={{
            position: 'absolute', left: `${thumbPct}%`,
            transform: 'translateX(-50%)',
            width: 28, height: 28, borderRadius: 14,
            background: '#fff',
            border: `3px solid ${Y2.VIOLET}`,
            boxShadow: '0 6px 14px rgba(107,43,255,0.4)',
            pointerEvents: 'none',
            transition: dragging ? 'none' : 'left 0.18s cubic-bezier(.2,.7,.3,1.4)',
          }}>
            <div style={{
              position: 'absolute', inset: 4, borderRadius: 8, background: Y2.GRAD,
            }}/>
          </div>
        </div>

        {/* tick labels */}
        <div style={{
          position: 'relative', height: 18, marginTop: 6,
          fontFamily: 'var(--font-mono)', fontSize: 10,
          color: Y2.INK_SOFT,
        }}>
          {TIERS.map((t, i) => {
            const left = (i / (TIERS.length - 1)) * 100;
            return (
              <div key={i} style={{
                position: 'absolute', left: `${left}%`,
                transform: 'translateX(-50%)',
                fontWeight: idx === i ? 800 : 500,
                color: idx === i ? Y2.VIOLET : Y2.INK_SOFT,
              }}>{i === 5 ? '200+' : t.ceiling}</div>
            );
          })}
        </div>
      </div>

      {/* ── LADDER PREVIEW ─────────────────────────────── */}
      <div style={{ margin: '0 16px 16px' }}>
        <div style={{
          fontSize: 10.5, fontWeight: 800, color: Y2.INK_SOFT,
          letterSpacing: 0.5, textTransform: 'uppercase',
          fontFamily: 'var(--font-display)', marginBottom: 8,
        }}>Your journey as you grow</div>
        <div style={{ display: 'flex', gap: 4, alignItems: 'stretch' }}>
          {TIERS.map((t, i) => {
            const on = i === idx;
            return (
              <div key={i} style={{
                flex: 1, padding: '8px 6px',
                borderRadius: 10,
                background: on ? Y2.GRAD : Y2.PAPER_2,
                color: on ? '#fff' : Y2.INK_SOFT,
                textAlign: 'center',
                boxShadow: on ? '0 6px 16px rgba(107,43,255,0.3)' : 'none',
                transition: 'all 0.18s',
                transform: on ? 'translateY(-2px)' : 'none',
              }}>
                <div style={{
                  fontFamily: 'var(--font-mono)', fontSize: 9,
                  letterSpacing: 0.3, fontWeight: 700,
                  opacity: on ? 0.85 : 0.7,
                }}>{t.range}</div>
                <div style={{
                  fontFamily: 'var(--font-display)', fontWeight: 900,
                  fontSize: 12, letterSpacing: -0.3, marginTop: 2,
                }}>${t.price}</div>
              </div>
            );
          })}
        </div>
      </div>

      {/* ── TRIAL CALLOUT ──────────────────────────────── */}
      <div style={{ margin: '0 16px 10px', textAlign: 'center' }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8,
          padding: '8px 14px', borderRadius: 999,
          background: `${Y2.LIME}25`, color: '#2A5C09',
          border: `1px solid ${Y2.LIME}55`,
          fontSize: 12.5, fontWeight: 700, fontFamily: 'var(--font-display)',
          letterSpacing: -0.1,
        }}>
          <span>✨</span>
          <span>14-day free trial — no charge until <b>{trialEnd}</b></span>
        </div>
      </div>

      {/* ── TRUST STRIP ────────────────────────────────── */}
      <div style={{
        margin: '0 16px 14px',
        textAlign: 'center', fontSize: 11.5, color: Y2.INK_SOFT,
        fontWeight: 500,
      }}>
        Cancel anytime <span style={{ opacity: 0.5, margin: '0 6px' }}>·</span>
        No setup fee <span style={{ opacity: 0.5, margin: '0 6px' }}>·</span>
        Used by 240+ youth pastors
      </div>

      {/* ── CTA ────────────────────────────────────────── */}
      <div style={{ padding: '0 16px' }}>
        <CTA2 full onClick={next}>Start 14-day free trial →</CTA2>
        <div style={{
          textAlign: 'center', marginTop: 10, fontSize: 11.5, color: Y2.INK_SOFT,
          lineHeight: 1.45,
        }}>
          Card required — no charge until <b style={{ color: Y2.INK }}>{trialEnd}</b>.
          We email you 3 days before the trial ends.
        </div>
      </div>

      <TF2/>
    </div>
  );
}

function Pill2({ children, color }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '4px 10px', borderRadius: 999,
      background: `${color}18`, color: color,
      fontSize: 11, fontWeight: 800, letterSpacing: 0.3,
      fontFamily: 'var(--font-display)', textTransform: 'uppercase',
    }}>{children}</span>
  );
}

function Trust({ icon, t }) {
  return (
    <div style={{ flex: 1 }}>
      <div style={{ fontSize: 16 }}>{icon}</div>
      <div style={{ fontSize: 11, fontWeight: 700, color: Y2.INK_SOFT, marginTop: 2 }}>{t}</div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 9 — STRIPE CHECKOUT (placeholder)
// ════════════════════════════════════════════════════════════════
function ScreenCheckout({ next, data, back }) {
  const tier = TIERS[data.pricingTierIdx ?? 0];
  const trialEnd = uM(() => {
    const d = new Date();
    d.setDate(d.getDate() + 14);
    return d.toLocaleDateString('en-US', { month: 'long', day: 'numeric' });
  }, []);

  return (
    <div className="scrollable" style={{ paddingTop: 56, paddingBottom: 16,
      background: Y2.PAPER_2, minHeight: '100%' }}>

      {/* Custom checkout-specific step indicator (replaces the wizard progress bar) */}
      <div style={{ padding: '4px 16px 12px' }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8,
          padding: '5px 12px', borderRadius: 999,
          background: '#fff', border: `1px solid ${Y2.INK_FAINT}`,
          fontSize: 11, fontWeight: 800, fontFamily: 'var(--font-display)',
          letterSpacing: 0.3, textTransform: 'uppercase',
          color: Y2.VIOLET,
        }}>
          <span style={{ width: 6, height: 6, borderRadius: 3, background: Y2.VIOLET }}/>
          Step 1 of 1 · Payment
        </div>
      </div>

      <div style={{ padding: '0 20px' }}>
        <h2 style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 28, letterSpacing: -1.1, lineHeight: 1.05,
          margin: '4px 0 8px',
        }}>Save your card to start your trial.</h2>
        <p style={{ fontSize: 13.5, color: Y2.INK_SOFT, margin: 0, lineHeight: 1.45 }}>
          You won't be charged today. Your first bill is{' '}
          <b style={{ color: Y2.INK }}>{trialEnd}</b>{' '}
          for <b style={{ color: Y2.INK }}>${tier.price}</b> ({tier.name} tier — {tier.range} active students).
        </p>
      </div>

      {/* Stripe placeholder */}
      <div style={{
        margin: '18px 16px 14px', padding: 18, borderRadius: 18,
        background: '#fff',
        border: `1.5px dashed ${Y2.INK_FAINT}`,
        textAlign: 'center',
      }}>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          marginBottom: 14,
        }}>
          <div style={{
            padding: '4px 10px', borderRadius: 6,
            background: '#635BFF', color: '#fff',
            fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 11,
            letterSpacing: 0.5,
          }}>stripe</div>
          <div style={{
            fontFamily: 'var(--font-mono)', fontSize: 10, color: Y2.INK_SOFT,
            letterSpacing: 0.4, textTransform: 'uppercase',
          }}>Payment Element</div>
        </div>

        {/* Mock card row */}
        <div style={{
          background: Y2.PAPER, borderRadius: 12, padding: '12px 14px',
          textAlign: 'left', marginBottom: 8,
        }}>
          <div style={{ fontSize: 10.5, fontWeight: 700, color: Y2.INK_SOFT,
            letterSpacing: 0.4, textTransform: 'uppercase', marginBottom: 4 }}>Card information</div>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            fontFamily: 'var(--font-mono)', fontSize: 14, fontWeight: 600, color: Y2.INK_SOFT,
          }}>
            <span>1234 1234 1234 1234</span>
            <span style={{ display: 'flex', gap: 4 }}>
              <span style={{ width: 28, height: 18, borderRadius: 3,
                background: 'linear-gradient(135deg, #1A1F71, #2A77C7)' }}/>
              <span style={{ width: 28, height: 18, borderRadius: 3,
                background: 'linear-gradient(135deg, #EB001B, #F79E1B)' }}/>
            </span>
          </div>
        </div>
        <div style={{
          display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8,
        }}>
          <div style={{ background: Y2.PAPER, borderRadius: 12, padding: '12px 14px', textAlign: 'left' }}>
            <div style={{ fontSize: 10.5, fontWeight: 700, color: Y2.INK_SOFT,
              letterSpacing: 0.4, textTransform: 'uppercase', marginBottom: 4 }}>Expiry</div>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: 14, color: Y2.INK_SOFT }}>MM / YY</div>
          </div>
          <div style={{ background: Y2.PAPER, borderRadius: 12, padding: '12px 14px', textAlign: 'left' }}>
            <div style={{ fontSize: 10.5, fontWeight: 700, color: Y2.INK_SOFT,
              letterSpacing: 0.4, textTransform: 'uppercase', marginBottom: 4 }}>CVC</div>
            <div style={{ fontFamily: 'var(--font-mono)', fontSize: 14, color: Y2.INK_SOFT }}>· · ·</div>
          </div>
        </div>

        <div style={{
          marginTop: 14, padding: '8px 12px',
          background: 'rgba(99,91,255,0.08)',
          borderRadius: 8, fontSize: 11, color: '#635BFF',
          fontFamily: 'var(--font-mono)', letterSpacing: 0.3,
        }}>
          Stripe Checkout renders here
        </div>
      </div>

      {/* Reassurance items */}
      <div style={{
        margin: '0 16px 14px',
        display: 'flex', flexDirection: 'column', gap: 8,
      }}>
        <Reassure icon="🔒" text="Card encrypted by Stripe — we never see it"/>
        <Reassure icon="📧" text="Email reminder 3 days before trial ends"/>
        <Reassure icon="🎯" text="Cancel any time from your dashboard"/>
      </div>

      <div style={{ padding: '0 16px' }}>
        <CTA2 full onClick={next}>Start my 14-day free trial</CTA2>
        <div style={{
          textAlign: 'center', marginTop: 10, fontSize: 11.5, color: Y2.INK_SOFT,
        }}>
          Need to adjust? <span onClick={back} style={{
            color: Y2.VIOLET, fontWeight: 700, cursor: 'pointer',
            textDecoration: 'underline',
          }}>Back to pricing</span>
        </div>
      </div>
    </div>
  );
}

function Reassure({ icon, text }) {
  return (
    <div style={{
      background: '#fff', borderRadius: 12,
      padding: '10px 14px',
      border: `1px solid ${Y2.INK_FAINT}`,
      display: 'flex', alignItems: 'center', gap: 12,
      fontSize: 13, color: Y2.INK, fontWeight: 500,
    }}>
      <div style={{
        width: 30, height: 30, borderRadius: 9,
        background: Y2.PAPER_2,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 15, flexShrink: 0,
      }}>{icon}</div>
      <span>{text}</span>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 10 — WELCOME / CONFETTI
// ════════════════════════════════════════════════════════════════
function ScreenWelcome({ data, go }) {
  const church = data.churchName || 'Northpoint';
  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: `radial-gradient(60% 50% at 50% 20%, ${Y2.PINK} 0%, ${Y2.VIOLET} 40%, ${Y2.VIOLET_DEEP} 90%)`,
      color: '#fff', overflow: 'hidden',
    }}>
      {/* CONFETTI */}
      {Array.from({ length: 60 }).map((_, i) => {
        const colors = [Y2.YELLOW, Y2.PINK, Y2.CYAN, Y2.LIME, '#fff'];
        return (
          <div key={i} style={{
            position: 'absolute',
            top: -20, left: `${(i * 17.3) % 100}%`,
            width: 6 + (i % 4) * 2, height: 8 + (i % 3) * 3,
            borderRadius: i % 2 ? 2 : '50%',
            background: colors[i % 5],
            animation: `confetti-fall ${2.5 + (i % 4) * 0.8}s ${(i % 12) * 0.18}s linear infinite`,
            opacity: 0.95,
          }}/>
        );
      })}

      {/* Hero pin pop */}
      <div style={{
        position: 'absolute', top: 100, left: '50%',
        transform: 'translateX(-50%)',
        animation: 'pop-in 0.8s cubic-bezier(0.32,1.6,0.64,1) both',
      }}>
        <div style={{ filter: 'drop-shadow(0 18px 30px rgba(255,214,10,0.45))' }}>
          <MP2 size={92} label={church[0]} gradient={`linear-gradient(135deg, ${Y2.YELLOW}, ${Y2.PINK})`}/>
        </div>
      </div>

      <div style={{
        position: 'absolute', top: 270, left: 0, right: 0,
        padding: '0 24px', textAlign: 'center',
      }}>
        <div style={{
          fontSize: 11, fontWeight: 800, opacity: 0.8,
          letterSpacing: 1.5, textTransform: 'uppercase',
          fontFamily: 'var(--font-display)',
        }}>You're live</div>
        <h2 style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 34, letterSpacing: -1.4, lineHeight: 1.02,
          margin: '10px 0 12px', textWrap: 'balance',
        }}>{church} is on the map.</h2>
        <p style={{
          fontSize: 15, opacity: 0.85, margin: 0, lineHeight: 1.45,
          textWrap: 'balance', maxWidth: 320, marginInline: 'auto',
        }}>Your youth group is up and running. What's next?</p>
      </div>

      <div style={{
        position: 'absolute', bottom: 30, left: 16, right: 16,
        display: 'flex', flexDirection: 'column', gap: 10,
      }}>
        <CTA2 full onClick={() => {}}>Add my first small group →</CTA2>
        <button onClick={() => {}} style={{
          width: '100%', padding: '14px 22px',
          background: 'rgba(255,255,255,0.12)',
          border: '1px solid rgba(255,255,255,0.22)',
          borderRadius: 999, color: '#fff',
          fontFamily: 'var(--font-display)', fontWeight: 700,
          fontSize: 15, letterSpacing: -0.2, cursor: 'pointer',
        }}>Take me to the dashboard</button>
        <div style={{
          textAlign: 'center', marginTop: 6, fontSize: 12, opacity: 0.7,
        }}>
          ✉ We sent your students an invite link by email.
        </div>
      </div>
    </div>
  );
}

window.ScreenTourSmallGroups = ScreenTourSmallGroups;
window.ScreenTourSafeChat = ScreenTourSafeChat;
window.ScreenTourEvents = ScreenTourEvents;
window.ScreenTourBible = ScreenTourBible;
window.ScreenPricing = ScreenPricing;
window.ScreenCheckout = ScreenCheckout;
window.ScreenWelcome = ScreenWelcome;
