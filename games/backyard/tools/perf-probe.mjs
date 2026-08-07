// Boots the game, waits, reports draw calls / triangles / fps.
import { chromium } from 'playwright';
const browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
page.on('pageerror', (e) => console.error('[pageerror]', e.message));
await page.goto('http://127.0.0.1:5199/', { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => !!window.__BY_ROOT, null, { timeout: 30000 });
await page.evaluate(async () => {
  const mem = {};
  window.storage = { async get(k) { return mem[k] ?? null; }, async set(k, v) { mem[k] = v; }, async delete(k) { delete mem[k]; } };
  window.YGTEEV_MEMBER = false;
  window.YGTEEV = { profile: { id: 'shotbot', name: 'ShotBot', xp: 99999 } };
  window.YGTEEV_API = null;
  const meta = await fetch('/node_modules/.vite/deps/_metadata.json').then((r) => r.json());
  const React = (await import(`/node_modules/.vite/deps/react.js?v=${meta.browserHash}`)).default;
  const mod = await import('/src/dragon-garden-quest.jsx');
  window.__BY_ROOT.render(React.createElement(mod.default));
});
try { await page.getByText('PLAY', { exact: false }).first().click({ timeout: 20000 }); } catch {}
await page.waitForFunction(() => window.__BY_G && window.__BY_G.__dev, null, { timeout: 30000 });
await page.evaluate(() => window.__BY_G.skipIntro && window.__BY_G.skipIntro());
await page.waitForTimeout(3000);
const info = await page.evaluate(() => new Promise((res) => {
  // sample inside a rAF registered from a rAF, so it runs AFTER the game's
  // render for that frame — renderer.info auto-resets at each render start.
  requestAnimationFrame(() => requestAnimationFrame(() =>
    res(window.__BY_G.__renderInfo ? window.__BY_G.__renderInfo() : null)));
}));
const fps = await page.evaluate(() => new Promise((res) => {
  let c = 0; const t0 = performance.now();
  const loop = () => { c++; if (performance.now() - t0 < 5000) requestAnimationFrame(loop); else res((c / 5).toFixed(1)); };
  requestAnimationFrame(loop);
}));
console.log(JSON.stringify({ ...info, fps }));
await browser.close();
