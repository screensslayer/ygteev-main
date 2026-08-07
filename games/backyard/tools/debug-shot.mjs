import { chromium } from 'playwright';
const browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
page.on('pageerror', (e) => console.error('[pageerror]', e.message));
page.on('console', (m) => { if (m.type() === 'error') console.error('[console]', m.text().slice(0, 200)); });
await page.goto('http://127.0.0.1:5199/', { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => !!window.__BY_ROOT, null, { timeout: 30000 });
const mountErr = await page.evaluate(async () => {
  try {
    const mem = {};
    window.storage = { async get(k) { return mem[k] ?? null; }, async set(k, v) { mem[k] = v; }, async delete(k) { delete mem[k]; } };
    window.YGTEEV_MEMBER = false;
    window.YGTEEV = { profile: { id: 'shotbot', name: 'ShotBot', xp: 99999 } };
    window.YGTEEV_API = null;
    const meta = await fetch('/node_modules/.vite/deps/_metadata.json').then((r) => r.json());
    const React = (await import(`/node_modules/.vite/deps/react.js?v=${meta.browserHash}`)).default;
    const mod = await import('/src/dragon-garden-quest.jsx');
    window.__BY_ROOT.render(React.createElement(mod.default));
    return 'mount-ok hash=' + meta.browserHash + ' hasDefault=' + !!mod.default;
  } catch (e) { return 'MOUNT-ERR: ' + String(e); }
});
console.log(mountErr);
await page.waitForTimeout(4000);
console.log('body text sample:', (await page.evaluate(() => document.body.innerText.slice(0, 300))).replace(/\n/g, ' | '));
console.log('canvas count:', await page.evaluate(() => document.querySelectorAll('canvas').length));
console.log('webgl ok:', await page.evaluate(() => { try { const c = document.createElement('canvas'); return !!c.getContext('webgl'); } catch { return false; } }));
await page.screenshot({ path: 'debug-stage1.png' });
console.log('G present:', await page.evaluate(() => !!window.__BY_G));
await browser.close();
