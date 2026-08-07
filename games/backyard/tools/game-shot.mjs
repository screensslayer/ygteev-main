// Headless screenshot harness for the Backyard game.
// Boots the game auth-less (console-mount into the page's own React root
// with stubbed YGTEEV globals), clicks PLAY, optionally teleports, waits
// for frames to settle, screenshots.
//
// usage: node game-shot.mjs <out.png> [--tp x,z] [--w 1280] [--h 800]
//        [--wait ms] [--eval "js after engine ready"] [--splash]
//        --splash: keep the title splash up (sample leaderboard rows) and
//                  screenshot the menu itself instead of entering the game.
import { chromium } from 'playwright';

const args = process.argv.slice(2);
const out = args[0];
function opt(name, dflt) {
  const i = args.indexOf('--' + name);
  return i >= 0 ? args[i + 1] : dflt;
}
const tp = opt('tp', null);
const splashOnly = args.includes('--splash');
const W = parseInt(opt('w', '1280'), 10);
const H = parseInt(opt('h', '800'), 10);
const extraWait = parseInt(opt('wait', '2500'), 10);
const evalJs = opt('eval', null);

const browser = await chromium.launch({
  headless: true,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});
const page = await browser.newPage({ viewport: { width: W, height: H } });
page.on('pageerror', (e) => console.error('[pageerror]', e.message));

await page.goto('http://127.0.0.1:5199/', { waitUntil: 'domcontentloaded' });
// main.jsx creates window.__BY_ROOT at module load — wait for it.
await page.waitForFunction(() => !!window.__BY_ROOT, null, { timeout: 30000 });

await page.evaluate(async (splashOnly) => {
  if (splashOnly) window.__BY_SPLASH_SAMPLE = 1;
  const mem = {};
  window.storage = {
    async get(k) { return mem[k] ?? null; },
    async set(k, v) { mem[k] = v; },
    async delete(k) { delete mem[k]; },
  };
  window.YGTEEV_MEMBER = false; // bridge collapsed; home + town reachable
  window.YGTEEV = { profile: { id: 'shotbot', name: 'ShotBot', xp: 99999 } };
  window.YGTEEV_API = null; // all backend paths are guarded no-ops
  const meta = await fetch('/node_modules/.vite/deps/_metadata.json').then((r) => r.json());
  const React = (await import(`/node_modules/.vite/deps/react.js?v=${meta.browserHash}`)).default;
  const mod = await import('/src/dragon-garden-quest.jsx');
  window.__BY_ROOT.render(React.createElement(mod.default));
}, splashOnly);

// Dismiss the title splash (unless we're here to photograph it).
if (!splashOnly) {
  try {
    await page.locator('img[alt="Start game"]').first().click({ timeout: 20000 });
  } catch {
    try {
      await page.getByText('START GAME', { exact: false }).first().click({ timeout: 3000 });
    } catch {
      try { await page.getByText('PLAY', { exact: false }).first().click({ timeout: 3000 }); } catch { /* may auto-start */ }
    }
  }
}

await page.waitForFunction(() => window.__BY_G && window.__BY_G.__dev, null, { timeout: 30000 });
await page.waitForTimeout(1500);

if (tp) {
  const [x, z] = tp.split(',').map(Number);
  await page.evaluate(([x, z]) => window.__BY_G.__tp(x, z), [x, z]);
}
if (evalJs) await page.evaluate(evalJs);
await page.waitForTimeout(extraWait);

await page.screenshot({ path: out });
console.log('wrote', out);
await browser.close();
