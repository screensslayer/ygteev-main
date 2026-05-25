// pastor-screens.jsx — 11 screens of the YGTeeV pastor onboarding wizard.
// Each screen is responsive: 375px mobile-first, but elegant at 480 wizard width.

const { useState: uS, useEffect: uE, useRef: uR, useMemo: uM } = React;
const Y = window.YG;
const { CTA, TrustFooter } = window;

// ════════════════════════════════════════════════════════════════
// SHARED UI BITS
// ════════════════════════════════════════════════════════════════

function Mark({ size = 28 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size * 0.28,
      background: Y.GRAD,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color: '#fff', fontFamily: 'var(--font-display)', fontWeight: 900,
      fontSize: size * 0.42, letterSpacing: -0.5,
      boxShadow: 'inset 0 -2px 4px rgba(0,0,0,0.2), inset 0 1.5px 0 rgba(255,255,255,0.3)',
    }}>YG</div>
  );
}

function Field({ label, value, onChange, placeholder, type = 'text', children, right }) {
  return (
    <label style={{
      display: 'block',
      background: '#fff', borderRadius: 14, padding: '10px 14px 12px',
      border: `1px solid ${Y.INK_FAINT}`,
      boxShadow: '0 1px 0 rgba(255,255,255,0.6) inset, 0 2px 6px rgba(26,19,48,0.04)',
      position: 'relative',
    }}>
      <div style={{
        fontSize: 10.5, fontWeight: 700, color: 'rgba(26,19,48,0.55)',
        letterSpacing: 0.4, textTransform: 'uppercase',
      }}>{label}</div>
      {children || (
        <input value={value || ''} onChange={(e) => onChange?.(e.target.value)}
          placeholder={placeholder} type={type}
          style={{
            border: 'none', outline: 'none', width: '100%',
            fontSize: 16, padding: '4px 0 0', color: Y.INK,
            fontFamily: 'var(--font-display)', fontWeight: 600,
            background: 'transparent',
          }}/>
      )}
      {right}
    </label>
  );
}
window.Field = Field;

function Pill({ children, color = Y.VIOLET, dark }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '4px 10px', borderRadius: 999,
      background: dark ? 'rgba(255,255,255,0.12)' : `${color}18`,
      color: dark ? '#fff' : color,
      fontSize: 11, fontWeight: 800, letterSpacing: 0.3,
      fontFamily: 'var(--font-display)',
      textTransform: 'uppercase',
    }}>{children}</span>
  );
}

// Mini placeholder image — diagonal stripes, monospace caption
function Ph({ h = 120, label, dark, rounded = 14 }) {
  return (
    <div style={{
      height: h, borderRadius: rounded,
      background: dark
        ? `repeating-linear-gradient(135deg, rgba(255,255,255,0.04) 0 2px, transparent 2px 14px), rgba(255,255,255,0.04)`
        : `repeating-linear-gradient(135deg, rgba(26,19,48,0.05) 0 2px, transparent 2px 14px), ${Y.PAPER_2}`,
      border: dark ? '1px solid rgba(255,255,255,0.1)' : `1px solid ${Y.INK_FAINT}`,
      color: dark ? 'rgba(255,255,255,0.6)' : Y.INK_SOFT,
      fontFamily: 'var(--font-mono)', fontSize: 11,
      letterSpacing: 0.5, textTransform: 'uppercase',
      display: 'flex', alignItems: 'flex-end', padding: 12,
    }}>{label}</div>
  );
}

// Stylized phone frame for tour visuals
function MiniPhone({ children, scale = 1, style = {} }) {
  return (
    <div style={{
      width: 240 * scale, height: 500 * scale,
      background: '#0a091f', borderRadius: 38 * scale,
      padding: 8 * scale,
      boxShadow: '0 30px 70px -20px rgba(0,0,0,0.5), inset 0 0 0 1px rgba(255,255,255,0.08)',
      position: 'relative',
      ...style,
    }}>
      <div style={{ position: 'absolute', top: 10 * scale, left: '50%', transform: 'translateX(-50%)',
        width: 90 * scale, height: 22 * scale, background: '#000', borderRadius: 14 * scale, zIndex: 4 }}/>
      <div style={{
        width: '100%', height: '100%', borderRadius: 30 * scale,
        background: '#fff', overflow: 'hidden', position: 'relative',
      }}>
        {children}
      </div>
    </div>
  );
}

// Gradient map pin (used everywhere)
function MapPin({ size = 44, label, gradient = Y.GRAD, animate }) {
  return (
    <div style={{
      width: size, height: size * 1.32, position: 'relative',
      filter: 'drop-shadow(0 8px 16px rgba(107,43,255,0.35))',
      animation: animate ? 'float-y 3s ease-in-out infinite' : undefined,
    }}>
      <div style={{
        width: size, height: size, borderRadius: '50% 50% 50% 0',
        background: gradient,
        transform: 'rotate(-45deg)',
        position: 'absolute', top: 0, left: 0,
        border: '3px solid #fff',
        boxShadow: 'inset 0 -3px 6px rgba(0,0,0,0.15)',
      }}/>
      <div style={{
        position: 'absolute', top: size * 0.2, left: size * 0.2,
        width: size * 0.6, height: size * 0.6,
        borderRadius: '50%', background: '#fff',
        color: Y.INK, fontFamily: 'var(--font-display)',
        fontWeight: 900, fontSize: size * 0.32,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        letterSpacing: -0.4,
      }}>{label || ''}</div>
    </div>
  );
}
window.MapPin = MapPin;

// ════════════════════════════════════════════════════════════════
// SCREEN 0 — MARKETING LANDING (scrollable)
// ════════════════════════════════════════════════════════════════
function ScreenLanding({ next, go }) {
  const [faq, setFaq] = uS(0);
  const faqs = [
    { q: "How is this different from a group text?",
      a: "Group texts share your cell number, leak to parents, and have zero safety guardrails. YGTeeV gives you moderated channels, auto-flagging, and a paper trail — without trading away your personal number." },
    { q: "Will my students actually use it?",
      a: "The teen side is built for them, not us. Gamified Bible plans, a pixel garden they level up, streaks. We've seen 68% of teens keep a streak past day 7." },
    { q: "What if some of my students aren't on social media?",
      a: "Perfect — that's exactly who YGTeeV is built for. It's parent-approved, closed, no infinite scroll, no strangers. Just your group." },
    { q: "Can I cancel?",
      a: "Cancel any time from your dashboard. We won't charge you during the 14-day trial — and we'll email you 3 days before it ends." },
  ];

  return (
    <div className="scrollable" style={{
      background: Y.PAPER, color: Y.INK,
      paddingBottom: 40,
    }}>
      {/* ── Hero ──────────────────────────────────────────── */}
      <section style={{
        position: 'relative', minHeight: 580,
        background: `radial-gradient(80% 60% at 50% 0%, ${Y.PINK} 0%, ${Y.VIOLET} 40%, ${Y.VIOLET_DEEP} 90%)`,
        color: '#fff',
        padding: '70px 22px 50px',
        overflow: 'hidden',
      }}>
        {/* grid overlay */}
        <div style={{
          position: 'absolute', inset: 0,
          backgroundImage: 'linear-gradient(rgba(255,255,255,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.06) 1px, transparent 1px)',
          backgroundSize: '40px 40px',
          maskImage: 'radial-gradient(70% 60% at 50% 30%, black 30%, transparent 80%)',
          WebkitMaskImage: 'radial-gradient(70% 60% at 50% 30%, black 30%, transparent 80%)',
        }}/>
        <div style={{ position: 'relative', zIndex: 2 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 26 }}>
            <Mark size={32}/>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 18, letterSpacing: -0.4 }}>
              YGTeeV
            </div>
            <div style={{ flex: 1 }}/>
            <button onClick={next} style={{
              padding: '7px 14px', borderRadius: 999,
              background: 'rgba(255,255,255,0.12)', border: '1px solid rgba(255,255,255,0.22)',
              color: '#fff', fontSize: 13, fontWeight: 700, fontFamily: 'var(--font-display)',
              cursor: 'pointer', letterSpacing: -0.1,
            }}>Sign in</button>
          </div>

          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '5px 12px', borderRadius: 999,
            background: 'rgba(255,255,255,0.14)',
            border: '1px solid rgba(255,255,255,0.22)',
            fontSize: 11.5, fontWeight: 700, letterSpacing: 0.3,
            textTransform: 'uppercase',
            fontFamily: 'var(--font-display)',
            marginBottom: 18,
          }}>
            <span style={{ width: 7, height: 7, borderRadius: 4, background: Y.LIME,
              boxShadow: `0 0 10px ${Y.LIME}` }}/>
            A student put you on YGTeeV
          </div>

          <h1 style={{
            fontFamily: 'var(--font-display)', fontWeight: 900,
            fontSize: 'clamp(34px, 9vw, 44px)', lineHeight: 0.98,
            letterSpacing: -1.6, margin: 0, textWrap: 'balance',
          }}>
            Your youth group,<br/>
            finally on a tap your<br/>
            <span style={{
              background: `linear-gradient(90deg, ${Y.YELLOW}, ${Y.LIME}, ${Y.CYAN})`,
              WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent',
            }}>students</span> will actually take.
          </h1>

          <p style={{
            fontSize: 16, lineHeight: 1.45, marginTop: 16, marginBottom: 26,
            color: 'rgba(255,255,255,0.85)', textWrap: 'balance', maxWidth: 360,
          }}>
            Group chat, events, Bible plans, and a pixel garden — wrapped into one app teens actually open. Built for the way your week runs.
          </p>

          <CTA full onClick={next}>Claim your group →</CTA>
          <div style={{
            marginTop: 14, fontSize: 13, opacity: 0.75, textAlign: 'center',
          }}>
            A student already added you? <u style={{ fontWeight: 700, opacity: 0.95 }}>Sign in instead</u>
          </div>

          {/* phone peek */}
          <div style={{
            marginTop: 36, display: 'flex', justifyContent: 'center', gap: 14, alignItems: 'flex-end',
          }}>
            <MiniPhone scale={0.62} style={{ transform: 'rotate(-6deg) translateY(8px)' }}>
              <ChatPreview/>
            </MiniPhone>
            <MiniPhone scale={0.7}>
              <GardenPreview/>
            </MiniPhone>
            <MiniPhone scale={0.62} style={{ transform: 'rotate(6deg) translateY(8px)' }}>
              <MapPreviewSmall/>
            </MiniPhone>
          </div>
        </div>
      </section>

      {/* ── Three feature cards ──────────────────────────── */}
      <section style={{ padding: '40px 18px 24px' }}>
        <div style={{
          fontSize: 12, fontWeight: 800, color: Y.VIOLET,
          letterSpacing: 1.5, textTransform: 'uppercase',
          fontFamily: 'var(--font-display)', textAlign: 'center', marginBottom: 8,
        }}>What you get</div>
        <h2 style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 28, letterSpacing: -1, margin: '0 0 26px',
          textAlign: 'center', lineHeight: 1.05, textWrap: 'balance',
        }}>One app. Less duct tape.</h2>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <FeatureCard
            tag="Safe chat" tagColor={Y.PINK}
            title="Every message moderated."
            body="Bullying, sexual content, self-harm — flagged the moment it happens and routed straight to your inbox."
            visual={<ChatFeatureViz/>}
          />
          <FeatureCard
            tag="Bible plans" tagColor={Y.VIOLET}
            title="Reading they'll actually finish."
            body="Daily plans, streaks, XP, and a pixel garden teens water by showing up. Every kid in your group gets Pro — free."
            visual={<GardenFeatureViz/>}
          />
          <FeatureCard
            tag="On the map" tagColor={Y.CYAN}
            title="A teen four blocks away can find you."
            body="Your group gets a public profile pin so new students can discover you — only the info you choose to share."
            visual={<MapFeatureViz/>}
          />
        </div>
      </section>

      {/* ── Pricing teaser ────────────────────────────────── */}
      <section style={{
        margin: '32px 18px',
        padding: '22px 20px',
        background: '#fff', borderRadius: 22,
        border: `1px solid ${Y.INK_FAINT}`,
        boxShadow: '0 12px 30px rgba(26,19,48,0.06)',
        textAlign: 'center',
      }}>
        <Pill color={Y.LIME === Y.LIME ? '#3B7A14' : Y.LIME}>14-day free trial</Pill>
        <div style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 38, letterSpacing: -1.4, marginTop: 10,
        }}>$29<span style={{ fontSize: 18, fontWeight: 700, opacity: 0.55 }}>/mo</span></div>
        <div style={{ fontSize: 13, color: Y.INK_SOFT, marginTop: 4, maxWidth: 260, marginInline: 'auto' }}>
          Pay for the size you actually have — starts at $29. Cancel anytime.
        </div>
      </section>

      {/* ── Testimonial ──────────────────────────────────── */}
      <section style={{
        margin: '28px 18px', padding: '24px 22px',
        background: `linear-gradient(140deg, ${Y.VIOLET_DEEP}, ${Y.VIOLET})`,
        color: '#fff', borderRadius: 22,
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{
          position: 'absolute', top: -18, left: 14,
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 120, color: Y.PINK, opacity: 0.85, lineHeight: 1,
        }}>"</div>
        <div style={{ position: 'relative', zIndex: 2 }}>
          <p style={{
            fontFamily: 'var(--font-display)', fontWeight: 700,
            fontSize: 20, letterSpacing: -0.4, lineHeight: 1.25,
            marginTop: 14, marginBottom: 18, textWrap: 'balance',
          }}>For the first time, I actually know who's reading their Bible.</p>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{
              width: 44, height: 44, borderRadius: 22,
              background: 'rgba(255,255,255,0.18)',
              border: '1.5px solid rgba(255,255,255,0.5)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: 'var(--font-display)', fontWeight: 900, fontSize: 14,
            }}>JR</div>
            <div>
              <div style={{ fontWeight: 800, fontSize: 14, fontFamily: 'var(--font-display)' }}>
                Pastor Jared Riggs
              </div>
              <div style={{ fontSize: 12, opacity: 0.75 }}>Northpoint · 240 students</div>
            </div>
          </div>
        </div>
      </section>

      {/* ── FAQ ───────────────────────────────────────────── */}
      <section style={{ padding: '20px 18px' }}>
        <h3 style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 22, letterSpacing: -0.8, margin: '0 0 14px',
        }}>Honest questions, honest answers</h3>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {faqs.map((f, i) => {
            const open = faq === i;
            return (
              <div key={i} onClick={() => setFaq(open ? -1 : i)} style={{
                background: '#fff', borderRadius: 16,
                border: `1px solid ${Y.INK_FAINT}`,
                padding: '14px 16px', cursor: 'pointer',
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{
                    fontFamily: 'var(--font-display)', fontWeight: 800,
                    fontSize: 15, letterSpacing: -0.2, flex: 1,
                  }}>{f.q}</div>
                  <div style={{
                    width: 22, height: 22, borderRadius: 11,
                    background: open ? Y.VIOLET : Y.PAPER_2,
                    color: open ? '#fff' : Y.INK, fontWeight: 900,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 14, transition: 'all 0.2s',
                    transform: open ? 'rotate(45deg)' : 'none',
                  }}>+</div>
                </div>
                {open && (
                  <div style={{
                    marginTop: 10, fontSize: 13.5, color: Y.INK_SOFT,
                    lineHeight: 1.5,
                  }}>{f.a}</div>
                )}
              </div>
            );
          })}
        </div>
      </section>

      {/* ── Final CTA ────────────────────────────────────── */}
      <section style={{ padding: '24px 18px 8px' }}>
        <CTA full onClick={next}>Claim your group →</CTA>
        <div style={{
          textAlign: 'center', marginTop: 12, fontSize: 12.5, color: Y.INK_SOFT,
        }}>14-day free trial. No credit card to start.</div>
      </section>

      {/* footer */}
      <footer style={{
        marginTop: 22, padding: '18px 22px',
        borderTop: `1px solid ${Y.INK_FAINT}`,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        fontSize: 11.5, color: Y.INK_SOFT,
      }}>
        <span>© 2026 YGTeeV</span>
        <div style={{ display: 'flex', gap: 14 }}>
          <a style={{ color: 'inherit' }}>Privacy</a>
          <a style={{ color: 'inherit' }}>Terms</a>
          <a style={{ color: 'inherit' }}>Contact</a>
        </div>
      </footer>
    </div>
  );
}

// Feature card with mini visual
function FeatureCard({ tag, tagColor, title, body, visual }) {
  return (
    <div style={{
      background: '#fff', borderRadius: 22,
      border: `1px solid ${Y.INK_FAINT}`,
      padding: 18, display: 'flex', gap: 14, alignItems: 'center',
      boxShadow: '0 4px 14px rgba(26,19,48,0.04)',
    }}>
      <div style={{ flex: 1 }}>
        <Pill color={tagColor}>{tag}</Pill>
        <div style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 18, letterSpacing: -0.5, lineHeight: 1.15,
          marginTop: 8,
        }}>{title}</div>
        <div style={{ fontSize: 13, color: Y.INK_SOFT, marginTop: 6, lineHeight: 1.4 }}>{body}</div>
      </div>
      <div style={{ flexShrink: 0 }}>{visual}</div>
    </div>
  );
}

// Tiny chat preview viz
function ChatFeatureViz() {
  return (
    <div style={{
      width: 96, height: 110, borderRadius: 16,
      background: `linear-gradient(160deg, ${Y.PINK}, ${Y.VIOLET})`,
      padding: 8, position: 'relative', overflow: 'hidden',
    }}>
      <div style={{
        background: 'rgba(255,255,255,0.92)', borderRadius: 8,
        padding: '5px 7px', fontSize: 8.5, color: Y.INK,
        marginBottom: 4, fontWeight: 600,
      }}>Hey pastor?</div>
      <div style={{
        background: 'rgba(255,255,255,0.92)', borderRadius: 8,
        padding: '5px 7px', fontSize: 8.5, color: 'rgba(26,19,48,0.4)',
        marginBottom: 4, fontWeight: 600, fontStyle: 'italic',
      }}>[redacted]</div>
      <div style={{
        background: Y.YELLOW, color: Y.INK, borderRadius: 8,
        padding: '5px 7px', fontSize: 8, fontWeight: 900,
        letterSpacing: 0.3, display: 'flex', alignItems: 'center', gap: 4,
      }}>⚠ FLAGGED</div>
    </div>
  );
}

function GardenFeatureViz() {
  return (
    <div style={{
      width: 96, height: 110, borderRadius: 16,
      background: `linear-gradient(180deg, #A0E5FF, #C8B5FF)`,
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{ position: 'absolute', top: 8, right: 10, width: 16, height: 16,
        borderRadius: 8, background: Y.YELLOW, boxShadow: `0 0 10px ${Y.YELLOW}` }}/>
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 38,
        background: 'linear-gradient(180deg, #4CC65A, #2B8A3E)' }}/>
      {/* trees as pure pixel shapes */}
      <div style={{ position: 'absolute', bottom: 24, left: 12 }}>
        <div style={{ width: 16, height: 22, background: '#1F7A2B', borderRadius: 8 }}/>
        <div style={{ width: 4, height: 6, background: '#6B3F1A', margin: '0 auto' }}/>
      </div>
      <div style={{ position: 'absolute', bottom: 24, left: 38 }}>
        <div style={{ width: 22, height: 28, background: '#2B8A3E', borderRadius: 11 }}/>
        <div style={{ width: 4, height: 8, background: '#6B3F1A', margin: '0 auto' }}/>
      </div>
      <div style={{ position: 'absolute', bottom: 24, right: 12 }}>
        <div style={{ width: 12, height: 14, background: '#4CC65A', borderRadius: 6 }}/>
        <div style={{ width: 3, height: 4, background: '#6B3F1A', margin: '0 auto' }}/>
      </div>
    </div>
  );
}

function MapFeatureViz() {
  return (
    <div style={{
      width: 96, height: 110, borderRadius: 16,
      background: '#EBF2F7', position: 'relative', overflow: 'hidden',
      border: `1px solid ${Y.INK_FAINT}`,
    }}>
      {/* fake streets */}
      <div style={{ position: 'absolute', top: 30, left: 0, right: 0, height: 1.5, background: '#D5DBE3' }}/>
      <div style={{ position: 'absolute', top: 60, left: 0, right: 0, height: 1.5, background: '#D5DBE3' }}/>
      <div style={{ position: 'absolute', top: 85, left: 0, right: 0, height: 1.5, background: '#D5DBE3' }}/>
      <div style={{ position: 'absolute', top: 0, bottom: 0, left: 28, width: 1.5, background: '#D5DBE3' }}/>
      <div style={{ position: 'absolute', top: 0, bottom: 0, left: 64, width: 1.5, background: '#D5DBE3' }}/>
      {/* park blob */}
      <div style={{ position: 'absolute', top: 36, left: 30, width: 30, height: 22, background: '#D5EBC7', borderRadius: 4 }}/>
      {/* pins */}
      <div style={{ position: 'absolute', top: 18, right: 12 }}>
        <MapPin size={20} label="N" gradient={`linear-gradient(135deg, ${Y.VIOLET}, ${Y.PINK})`}/>
      </div>
      <div style={{ position: 'absolute', top: 50, left: 12, opacity: 0.55 }}>
        <MapPin size={14} label="" gradient={`linear-gradient(135deg, ${Y.CYAN}, ${Y.VIOLET})`}/>
      </div>
      <div style={{ position: 'absolute', top: 70, right: 30, opacity: 0.55 }}>
        <MapPin size={14} label="" gradient={`linear-gradient(135deg, ${Y.LIME}, ${Y.CYAN})`}/>
      </div>
    </div>
  );
}

// Mini phone previews for hero
function ChatPreview() {
  return (
    <div style={{
      width: '100%', height: '100%',
      background: `linear-gradient(180deg, #14123c, #1A1428)`,
      color: '#fff', padding: '32px 10px 10px',
    }}>
      <div style={{ fontSize: 9, fontWeight: 800, opacity: 0.6, fontFamily: 'var(--font-display)' }}>
        Wed-Night Group
      </div>
      <div style={{ background: 'rgba(255,255,255,0.08)', borderRadius: 9,
        padding: '6px 8px', fontSize: 9, marginTop: 8, fontWeight: 600 }}>
        Pizza after small group? 🍕
      </div>
      <div style={{ background: Y.PINK, borderRadius: 9, padding: '6px 8px', fontSize: 9,
        marginTop: 5, alignSelf: 'flex-end', maxWidth: '80%', marginLeft: 'auto', fontWeight: 700 }}>
        I'm in!
      </div>
      <div style={{ background: Y.YELLOW, color: Y.INK, borderRadius: 9,
        padding: '6px 8px', fontSize: 8, marginTop: 14, fontWeight: 800,
        boxShadow: `0 0 20px ${Y.YELLOW}55` }}>
        ⚠ 1 message flagged
      </div>
    </div>
  );
}
function GardenPreview() {
  return (
    <div style={{
      width: '100%', height: '100%',
      background: `linear-gradient(180deg, #A0E5FF, #C8B5FF)`,
      position: 'relative', padding: '32px 10px 10px',
    }}>
      <div style={{
        fontSize: 9, fontWeight: 800, color: Y.INK, fontFamily: 'var(--font-display)',
      }}>Your garden</div>
      <div style={{
        position: 'absolute', top: 16, right: 14,
        background: Y.YELLOW, borderRadius: 999,
        padding: '2px 8px', fontSize: 9, fontWeight: 900,
        color: Y.INK, fontFamily: 'var(--font-display)',
      }}>🔥 12</div>
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 90,
        background: 'linear-gradient(180deg, #4CC65A, #2B8A3E)' }}/>
      <div style={{ position: 'absolute', bottom: 60, left: 24 }}>
        <div style={{ width: 26, height: 36, background: '#1F7A2B', borderRadius: 12 }}/>
        <div style={{ width: 5, height: 9, background: '#6B3F1A', margin: '0 auto' }}/>
      </div>
      <div style={{ position: 'absolute', bottom: 60, right: 26 }}>
        <div style={{ width: 22, height: 28, background: '#2B8A3E', borderRadius: 10 }}/>
        <div style={{ width: 4, height: 8, background: '#6B3F1A', margin: '0 auto' }}/>
      </div>
      <div style={{ position: 'absolute', top: 22, right: 60, color: Y.YELLOW, fontSize: 14 }}>✦</div>
    </div>
  );
}
function MapPreviewSmall() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#EBF2F7',
      position: 'relative', padding: '32px 0 0' }}>
      <div style={{ position: 'absolute', top: 36, left: 0, right: 0, height: 1.5, background: '#D5DBE3' }}/>
      <div style={{ position: 'absolute', top: 70, left: 0, right: 0, height: 1.5, background: '#D5DBE3' }}/>
      <div style={{ position: 'absolute', top: 110, left: 0, right: 0, height: 1.5, background: '#D5DBE3' }}/>
      <div style={{ position: 'absolute', top: 0, bottom: 0, left: 40, width: 1.5, background: '#D5DBE3' }}/>
      <div style={{ position: 'absolute', top: 0, bottom: 0, right: 50, width: 1.5, background: '#D5DBE3' }}/>
      <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -100%)' }}>
        <MapPin size={36} label="N" animate/>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 1 — CREATE ACCOUNT
// ════════════════════════════════════════════════════════════════
function ScreenCreate({ data, set, next }) {
  const [tab, setTab] = uS('email');
  const [showPw, setShowPw] = uS(false);
  const strength = uM(() => {
    const p = data.password || '';
    let s = 0;
    if (p.length >= 8) s++;
    if (/[A-Z]/.test(p)) s++;
    if (/\d/.test(p)) s++;
    if (/[^A-Za-z0-9]/.test(p)) s++;
    return s;
  }, [data.password]);
  const strengthLabel = ['Weak', 'Okay', 'Good', 'Strong'][Math.max(strength - 1, 0)] || 'Weak';
  const strengthColor = [Y.PINK, Y.YELLOW, Y.CYAN, Y.LIME][Math.max(strength - 1, 0)] || Y.PINK;

  return (
    <div className="scrollable" style={{ paddingTop: 70, paddingBottom: 16 }}>
      <div style={{ padding: '0 20px' }}>
        <Mark size={36}/>
        <h2 style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 30, letterSpacing: -1.2, lineHeight: 1.05,
          margin: '20px 0 6px',
        }}>Welcome to YGTeeV.</h2>
        <p style={{ fontSize: 15, color: Y.INK_SOFT, margin: 0, lineHeight: 1.4 }}>
          Let's get your group on the map.
        </p>
      </div>

      <div style={{ padding: '18px 16px 0' }}>
        {/* Tab strip */}
        <div style={{
          display: 'grid', gridTemplateColumns: '1fr 1fr 1fr',
          background: Y.PAPER_2, borderRadius: 14, padding: 4, gap: 2,
        }}>
          {['email', 'apple', 'google'].map(t => {
            const on = tab === t;
            return (
              <button key={t} onClick={() => setTab(t)} style={{
                padding: '9px 6px', borderRadius: 10,
                background: on ? '#fff' : 'transparent',
                border: 'none', color: Y.INK,
                fontSize: 13, fontWeight: 700, fontFamily: 'var(--font-display)',
                letterSpacing: -0.1, cursor: 'pointer',
                boxShadow: on ? '0 2px 6px rgba(26,19,48,0.08)' : 'none',
                transition: 'all 0.18s',
              }}>
                {t === 'email' ? 'Email' : t === 'apple' ? ' Apple' : 'Google'}
              </button>
            );
          })}
        </div>

        {tab === 'email' ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 14 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              <Field label="First name" value={data.firstName} onChange={(v) => set({ firstName: v })}/>
              <Field label="Last name" value={data.lastName} onChange={(v) => set({ lastName: v })}/>
            </div>
            <Field label="Work email" value={data.email} onChange={(v) => set({ email: v })} type="email"/>
            <Field label="Password" type={showPw ? 'text' : 'password'}
              value={data.password} onChange={(v) => set({ password: v })}
              right={
                <div onClick={() => setShowPw(s => !s)} style={{
                  position: 'absolute', top: 14, right: 14, cursor: 'pointer',
                  fontSize: 11, fontWeight: 700, color: Y.VIOLET, letterSpacing: 0.3,
                  textTransform: 'uppercase', fontFamily: 'var(--font-display)',
                }}>{showPw ? 'hide' : 'show'}</div>
              }/>
            {/* strength meter */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ flex: 1, height: 4, borderRadius: 2, background: Y.INK_FAINT, overflow: 'hidden' }}>
                <div style={{
                  width: `${(strength / 4) * 100}%`, height: '100%',
                  background: strengthColor, transition: 'all 0.2s',
                }}/>
              </div>
              <div style={{
                fontSize: 11, fontWeight: 800, color: strengthColor,
                fontFamily: 'var(--font-display)', letterSpacing: 0.3,
                textTransform: 'uppercase', minWidth: 50, textAlign: 'right',
              }}>{strengthLabel}</div>
            </div>

            <div style={{ marginTop: 8 }}>
              <CTA full onClick={next}>Create account →</CTA>
            </div>
          </div>
        ) : (
          <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div style={{
              padding: '20px 16px', background: '#fff',
              border: `1px solid ${Y.INK_FAINT}`, borderRadius: 16,
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{
                width: 38, height: 38, borderRadius: 10,
                background: tab === 'apple' ? '#000' : '#fff',
                border: tab === 'apple' ? 'none' : `1px solid ${Y.INK_FAINT}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: tab === 'apple' ? '#fff' : 'inherit',
              }}>
                {tab === 'apple' ? (
                  <svg width="20" height="22" viewBox="0 0 20 22" fill="currentColor">
                    <path d="M14.7 11.4c0-2.5 2-3.7 2.1-3.8-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.8-1.6 0-3.2.9-4 2.4-1.7 3-.4 7.4 1.2 9.8.8 1.2 1.7 2.5 3 2.4 1.2 0 1.7-.8 3.1-.8 1.5 0 1.9.8 3.2.8 1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.8-.1 0-2.5-1-2.5-3.8zM12.4 4.1c.7-.8 1.1-1.9 1-3-.9 0-2.1.6-2.7 1.4-.6.7-1.2 1.8-1 2.9 1 .1 2-.5 2.7-1.3z"/>
                  </svg>
                ) : (
                  <svg width="20" height="20" viewBox="0 0 24 24">
                    <path fill="#4285F4" d="M22.5 12.3c0-.8-.1-1.5-.2-2.3H12v4.3h5.9c-.3 1.4-1 2.5-2.2 3.3v2.8h3.6c2.1-2 3.2-4.8 3.2-8.1z"/>
                    <path fill="#34A853" d="M12 23c2.9 0 5.4-1 7.2-2.6l-3.6-2.8c-1 .7-2.3 1.1-3.6 1.1-2.8 0-5.2-1.9-6-4.4H2.3v2.8C4.1 20.6 7.8 23 12 23z"/>
                    <path fill="#FBBC05" d="M6 14.3c-.3-.7-.4-1.5-.4-2.3s.1-1.6.4-2.3V6.9H2.3C1.5 8.4 1 10.2 1 12s.5 3.6 1.3 5.1L6 14.3z"/>
                    <path fill="#EA4335" d="M12 5.5c1.6 0 3 .5 4.1 1.6l3.2-3.2C17.4 2 14.9 1 12 1 7.8 1 4.1 3.4 2.3 6.9L6 9.7c.8-2.5 3.2-4.2 6-4.2z"/>
                  </svg>
                )}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 15 }}>
                  Continue with {tab === 'apple' ? 'Apple' : 'Google'}
                </div>
                <div style={{ fontSize: 12, color: Y.INK_SOFT, marginTop: 1 }}>
                  We'll use your name & email — nothing posted, nothing shared.
                </div>
              </div>
            </div>
            <CTA full onClick={next}>Continue →</CTA>
          </div>
        )}

        <div style={{
          textAlign: 'center', fontSize: 12.5, color: Y.INK_SOFT, marginTop: 18,
        }}>
          Already have an account? <b style={{ color: Y.VIOLET, cursor: 'pointer' }}>Sign in</b>
        </div>
      </div>

      <TrustFooter/>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 2 — GROUP LOCATION
// ════════════════════════════════════════════════════════════════
function ScreenGroup({ data, set, next }) {
  return (
    <div className="scrollable" style={{ paddingTop: 60, paddingBottom: 16 }}>
      <div style={{ padding: '0 20px' }}>
        <Pill color={Y.VIOLET}>Step 2 of 8</Pill>
        <h2 style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 30, letterSpacing: -1.2, lineHeight: 1.05,
          margin: '10px 0 6px',
        }}>Where's your group?</h2>
        <p style={{ fontSize: 14.5, color: Y.INK_SOFT, margin: 0, lineHeight: 1.4 }}>
          So we can put you on the map for students nearby.
        </p>
      </div>

      {/* Map preview */}
      <div style={{
        margin: '18px 16px 16px',
        height: 200, borderRadius: 18, overflow: 'hidden',
        position: 'relative', background: '#EBF2F7',
        border: `1px solid ${Y.INK_FAINT}`,
      }}>
        {/* streets */}
        {[40, 90, 140, 180].map(y => (
          <div key={'h' + y} style={{ position: 'absolute', top: y, left: 0, right: 0,
            height: y === 90 ? 6 : 1.5, background: y === 90 ? '#fff' : '#D5DBE3' }}/>
        ))}
        {[60, 140, 220, 300].map(x => (
          <div key={'v' + x} style={{ position: 'absolute', top: 0, bottom: 0, left: x,
            width: x === 140 ? 6 : 1.5, background: x === 140 ? '#fff' : '#D5DBE3' }}/>
        ))}
        {/* park */}
        <div style={{ position: 'absolute', top: 100, left: 150, width: 90, height: 60,
          background: '#D5EBC7', borderRadius: 4 }}/>
        {/* river */}
        <div style={{ position: 'absolute', top: 0, bottom: 0, left: 280, width: 30,
          background: '#BDD8E8' }}/>
        {/* the pin */}
        <div style={{
          position: 'absolute', top: 90, left: '50%',
          animation: 'pin-drop 0.9s cubic-bezier(0.32,1.6,0.64,1) both',
        }}>
          <MapPin size={42} label="N" animate/>
        </div>
        {/* label chip */}
        <div style={{
          position: 'absolute', bottom: 12, left: 12,
          background: 'rgba(255,255,255,0.95)', borderRadius: 10,
          padding: '5px 10px', fontSize: 11, fontWeight: 700,
          color: Y.INK, fontFamily: 'var(--font-display)',
          boxShadow: '0 4px 12px rgba(26,19,48,0.1)',
        }}>📍 {data.addressCity || 'Charlotte, NC'}</div>
      </div>

      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <Field label="Church name" value={data.churchName}
          onChange={(v) => set({ churchName: v })}
          placeholder="Northpoint Community Church"/>
        <Field label="Address" value={data.addressLine}
          onChange={(v) => set({ addressLine: v })}
          placeholder="4350 Steele Creek Rd"
          right={
            <div style={{
              position: 'absolute', top: 12, right: 14,
              fontSize: 11, fontWeight: 700, color: Y.VIOLET,
              fontFamily: 'var(--font-display)', letterSpacing: 0.3,
              textTransform: 'uppercase',
            }}>autofill</div>
          }/>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <Field label="Meeting day" value={data.meetingDay}
            onChange={(v) => set({ meetingDay: v })}/>
          <Field label="Time" value={data.meetingTime}
            onChange={(v) => set({ meetingTime: v })}/>
        </div>
      </div>

      <div style={{ padding: '18px 16px 0' }}>
        <CTA full onClick={next}>Looks right →</CTA>
      </div>
      <TrustFooter/>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// SCREEN 3 — BRAND YOUR GROUP
// ════════════════════════════════════════════════════════════════
const GRADIENTS = [
  [Y.VIOLET, Y.PINK],
  [Y.CYAN, Y.VIOLET],
  [Y.LIME, Y.CYAN],
  [Y.YELLOW, '#FF6B35'],
];

function ScreenBrand({ data, set, next }) {
  const [from, to] = GRADIENTS[data.gradient] || GRADIENTS[0];
  const grad = `linear-gradient(135deg, ${from}, ${to})`;
  const initials = (data.groupName || 'Northpoint Students').split(' ').filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase();

  return (
    <div className="scrollable" style={{ paddingTop: 60, paddingBottom: 16 }}>
      <div style={{ padding: '0 20px' }}>
        <Pill color={Y.VIOLET}>Step 3 of 8</Pill>
        <h2 style={{
          fontFamily: 'var(--font-display)', fontWeight: 900,
          fontSize: 30, letterSpacing: -1.2, lineHeight: 1.05,
          margin: '10px 0 6px',
        }}>Brand your group.</h2>
        <p style={{ fontSize: 14.5, color: Y.INK_SOFT, margin: 0, lineHeight: 1.4 }}>
          This is what your pin and your public profile will look like.
        </p>
      </div>

      {/* LIVE PREVIEW */}
      <div style={{
        margin: '18px 16px',
        padding: 16, borderRadius: 22,
        background: 'linear-gradient(180deg, #EBF2F7 0%, #DAE8F0 100%)',
        position: 'relative',
        border: `1px solid ${Y.INK_FAINT}`,
      }}>
        <div style={{
          position: 'absolute', top: 10, right: 12,
          fontFamily: 'var(--font-mono)', fontSize: 10, fontWeight: 700,
          color: Y.INK_SOFT, letterSpacing: 0.4, textTransform: 'uppercase',
        }}>Live preview</div>

        <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
          {/* Map pin */}
          <div style={{ flexShrink: 0, paddingTop: 18 }}>
            <MapPin size={56} label={initials.slice(0, 1)} gradient={grad}/>
          </div>
          {/* Profile card */}
          <div style={{
            flex: 1, background: '#fff', borderRadius: 14, padding: 12,
            boxShadow: '0 8px 24px rgba(26,19,48,0.08)',
          }}>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <div style={{
                width: 38, height: 38, borderRadius: 12, background: grad,
                color: '#fff', fontFamily: 'var(--font-display)', fontWeight: 900,
                fontSize: 14, letterSpacing: -0.3,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: 'inset 0 -2px 4px rgba(0,0,0,0.18)',
              }}>{initials}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800,
                  fontSize: 13, letterSpacing: -0.2, lineHeight: 1.1 }}>
                  {data.groupName || 'Your group name'}
                </div>
                <div style={{ fontSize: 10.5, color: Y.INK_SOFT, marginTop: 2 }}>
                  {data.meetingDay} · {data.meetingTime}
                </div>
              </div>
              {data.publicOnMap && (
                <div style={{
                  background: Y.LIME, color: Y.INK, borderRadius: 999,
                  padding: '2px 6px', fontSize: 8.5, fontWeight: 900,
                  fontFamily: 'var(--font-display)', letterSpacing: 0.3,
                }}>ON MAP</div>
              )}
            </div>
            <div style={{
              fontSize: 11, color: Y.INK_SOFT, marginTop: 8,
              lineHeight: 1.4, minHeight: 30,
            }}>
              {data.description || <span style={{ fontStyle: 'italic', opacity: 0.6 }}>Your two-line description shows here.</span>}
            </div>
          </div>
        </div>
      </div>

      {/* Form */}
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <Field label="Youth group name" value={data.groupName}
          onChange={(v) => set({ groupName: v })}
          placeholder="Northpoint Students"/>

        {/* Logo upload zone */}
        <div style={{
          background: '#fff', borderRadius: 14, padding: '12px 14px',
          border: `1.5px dashed ${Y.INK_FAINT}`,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{
            width: 44, height: 44, borderRadius: 12, background: grad,
            color: '#fff', fontFamily: 'var(--font-display)', fontWeight: 900,
            fontSize: 16, letterSpacing: -0.4,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: 'inset 0 -2px 4px rgba(0,0,0,0.18)',
          }}>{initials}</div>
          <div style={{ flex: 1 }}>
            <div style={{
              fontSize: 10.5, fontWeight: 700, color: 'rgba(26,19,48,0.55)',
              letterSpacing: 0.4, textTransform: 'uppercase',
            }}>Logo (optional)</div>
            <div style={{ fontSize: 13, color: Y.INK, marginTop: 1, fontWeight: 600, fontFamily: 'var(--font-display)' }}>
              Drag in — png, jpg, svg · 5MB max
            </div>
          </div>
          <button style={{
            padding: '7px 12px', borderRadius: 999,
            background: Y.PAPER_2, border: 'none', color: Y.INK,
            fontSize: 12, fontWeight: 700, fontFamily: 'var(--font-display)',
            cursor: 'pointer',
          }}>Choose</button>
        </div>

        {/* Gradient picker */}
        <div style={{
          background: '#fff', borderRadius: 14, padding: '12px 14px',
          border: `1px solid ${Y.INK_FAINT}`,
        }}>
          <div style={{
            fontSize: 10.5, fontWeight: 700, color: 'rgba(26,19,48,0.55)',
            letterSpacing: 0.4, textTransform: 'uppercase', marginBottom: 10,
          }}>Pin color</div>
          <div style={{ display: 'flex', gap: 10 }}>
            {GRADIENTS.map((g, i) => {
              const on = data.gradient === i;
              return (
                <button key={i} onClick={() => set({ gradient: i })} style={{
                  width: 44, height: 44, borderRadius: 14,
                  background: `linear-gradient(135deg, ${g[0]}, ${g[1]})`,
                  border: on ? `2.5px solid ${Y.INK}` : '2.5px solid transparent',
                  cursor: 'pointer', padding: 0,
                  boxShadow: on ? '0 4px 12px rgba(26,19,48,0.2)' : 'inset 0 -2px 4px rgba(0,0,0,0.2)',
                  transition: 'all 0.18s',
                  transform: on ? 'scale(1.06)' : 'none',
                }}/>
              );
            })}
            <button style={{
              width: 44, height: 44, borderRadius: 14,
              background: '#fff', border: `1.5px dashed ${Y.INK_FAINT}`,
              color: Y.INK_SOFT, fontWeight: 900, fontSize: 16,
              cursor: 'pointer',
            }}>+</button>
          </div>
        </div>

        {/* Description */}
        <div style={{
          background: '#fff', borderRadius: 14, padding: '10px 14px 12px',
          border: `1px solid ${Y.INK_FAINT}`,
        }}>
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          }}>
            <div style={{
              fontSize: 10.5, fontWeight: 700, color: 'rgba(26,19,48,0.55)',
              letterSpacing: 0.4, textTransform: 'uppercase',
            }}>Description</div>
            <div style={{ fontSize: 10, color: Y.INK_SOFT, fontFamily: 'var(--font-mono)' }}>
              {(data.description || '').length}/200
            </div>
          </div>
          <textarea value={data.description}
            onChange={(e) => set({ description: e.target.value.slice(0, 200) })}
            placeholder="Two lines on what your group is about."
            rows={2}
            style={{
              border: 'none', outline: 'none', width: '100%',
              fontSize: 14, padding: '6px 0 0', color: Y.INK,
              fontFamily: 'var(--font-body)', fontWeight: 500,
              background: 'transparent', resize: 'none',
              lineHeight: 1.4,
            }}/>
        </div>

        {/* Public toggle */}
        <div style={{
          background: '#fff', borderRadius: 14, padding: '14px 16px',
          border: `1px solid ${Y.INK_FAINT}`,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800,
              fontSize: 14, letterSpacing: -0.2 }}>
              Public on the map
            </div>
            <div style={{ fontSize: 11.5, color: Y.INK_SOFT, marginTop: 2, lineHeight: 1.35 }}>
              New students nearby can see your group. You approve every join.
            </div>
          </div>
          <button onClick={() => set({ publicOnMap: !data.publicOnMap })} style={{
            width: 44, height: 26, borderRadius: 14,
            background: data.publicOnMap ? Y.VIOLET : 'rgba(26,19,48,0.15)',
            border: 'none', padding: 0, position: 'relative', cursor: 'pointer',
            transition: 'background 0.2s',
          }}>
            <div style={{
              position: 'absolute', top: 3, left: data.publicOnMap ? 21 : 3,
              width: 20, height: 20, borderRadius: 10, background: '#fff',
              boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
              transition: 'left 0.2s',
            }}/>
          </button>
        </div>
      </div>

      <div style={{ padding: '18px 16px 0' }}>
        <CTA full onClick={next}>Looks good →</CTA>
      </div>
      <TrustFooter/>
    </div>
  );
}

window.ScreenLanding = ScreenLanding;
window.ScreenCreate = ScreenCreate;
window.ScreenGroup = ScreenGroup;
window.ScreenBrand = ScreenBrand;
