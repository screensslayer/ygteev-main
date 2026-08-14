// Bake the Character Studio item icons.
//
//   node tools/bake-item-icons.mjs        (dev server must be on :5199)
//
// Each icon is the REAL game mesh: the avatar rig is built and dressed as
// normal, everything except that one item is hidden, and the camera frames
// what is left. Re-run after changing any outfit mesh or adding an option.
// Writes public/ui/kit/opt/{slot}-{value}.png.
import { chromium } from 'playwright';
import fs from 'fs';
const OUT = process.argv[2] || new URL('../public/ui/kit/opt', import.meta.url).pathname;
const browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader','--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 500, height: 400 } });
page.on('pageerror', (e) => console.error('[pageerror]', e.message));
await page.goto('http://127.0.0.1:5199/', { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => !!window.__BY_ROOT);
await page.evaluate(async () => {
  const mem = {};
  window.storage = { async get(k){return mem[k]??null;}, async set(k,v){mem[k]=v;}, async delete(k){delete mem[k];} };
  window.YGTEEV_MEMBER = false; window.YGTEEV = { profile: { id:'me', name:'Jim', xp:4000 } }; window.YGTEEV_API = null;
  const meta = await fetch('/node_modules/.vite/deps/_metadata.json').then(r=>r.json());
  const React = (await import(`/node_modules/.vite/deps/react.js?v=${meta.browserHash}`)).default;
  const mod = await import('/src/dragon-garden-quest.jsx');
  window.__BY_ROOT.render(React.createElement(mod.default));
});
await page.locator('img[alt="Start game"]').first().click({ timeout: 20000 });
await page.waitForTimeout(2500);
await page.evaluate(() => window.__BY_G.skipIntro && window.__BY_G.skipIntro());
await page.waitForTimeout(1200);

// Per-category staging. Hair and skin force the hat off — under a straw brim
// every cut looks identical. The backpack only exists on the character's back,
// so accessories are shot from behind unless the item lives on the front.
// Item-only icons: the mesh alone, no wearer. "none" has no mesh, so it is
// skipped here — the UI draws a plain "None" tile for it.
const FRONT_ACC = new Set(['glasses', 'basket', 'stick']);
const CATS = [
  { slot: 'hat',       vals: ['straw','beanie','cap','bucket','crown','shroom'] },
  { slot: 'hairStyle', vals: null },
  { slot: 'style',     vals: null },
  { slot: 'accessory', vals: ['basket','pack','satchel','glasses','scarf','stick'],
    spin: (v) => (FRONT_ACC.has(v) ? 0.5 : 2.6) },
  { slot: 'skin',      vals: null },
];
fs.mkdirSync(OUT, { recursive: true });
for (const c of CATS) {
  const vals = c.vals || await page.evaluate((k) => {
    const L = { hairStyle: window.__BY_HAIR_STYLES, style: window.__BY_STYLE_OPTS, skin: window.__BY_SKIN };
    return L[k] || [];
  }, c.slot);
  let n = 0;
  for (const v of vals) {
    const spin = c.spin ? c.spin(v) : null;
    const url = await page.evaluate(([slot, v, spin]) => window.__BY_G.renderItemIcon(slot, v, 192, spin),
                                    [c.slot, v, spin]);
    if (!url) { console.log('  no mesh for', c.slot, v); continue; }
    fs.writeFileSync(`${OUT}/${c.slot}-${String(v).replace('#','')}.png`, Buffer.from(url.split(',')[1], 'base64'));
    n++;
  }
  console.log(c.slot, '->', n, 'icons');
}
await browser.close();
