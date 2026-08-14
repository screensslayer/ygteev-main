// Avatar screenshot suite — used by the AAA-avatar workflow loop.
// usage: node tools/avatar-shots.mjs <prefix>
// Writes <prefix>-{preset}-{a,b}.png (wardrobe cam, 2 angles), <prefix>-walk.png,
// and <prefix>-portrait.png (the actual HUD medallion render).
import { chromium } from 'playwright';
import fs from 'fs';
const prefix = process.argv[2] || '/tmp/avatar';
const b = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await b.newPage({ viewport: { width: 430, height: 800 } });
page.on('pageerror', (e) => console.error('[pageerror]', e.message));
await page.goto('http://127.0.0.1:5199/', { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => !!window.__BY_ROOT, null, { timeout: 30000 });
await page.evaluate(async () => {
  const mem = { 'garden-intro': { value: '1' } };
  window.storage = { async get(k) { return mem[k] ?? null; }, async set(k, v) { mem[k] = { value: v }; }, async delete(k) { delete mem[k]; } };
  window.YGTEEV_MEMBER = false;
  window.YGTEEV = { profile: { id: 'shotbot', name: 'Jim', xp: 902 } };
  window.YGTEEV_API = null;
  const meta = await fetch('/node_modules/.vite/deps/_metadata.json').then((r) => r.json());
  const React = (await import(`/node_modules/.vite/deps/react.js?v=${meta.browserHash}`)).default;
  window.__BY_ROOT.render(React.createElement((await import('/src/dragon-garden-quest.jsx')).default));
});
await page.locator('img[alt="Start game"]').first().click({ timeout: 20000 });
await page.waitForFunction(() => window.__BY_G && window.__BY_G.__dev, null, { timeout: 30000 });
await page.waitForTimeout(2500);
await page.evaluate(() => { const G = window.__BY_G; G.hungerRate = 0; G.turtleCd = 99999; G.hunger = 80; });

const PRESETS = {
  default: {}, // tee + crop + straw — the out-of-box look
  bold:  { skin: 0xd19a6b, hair: 0x241813, hairStyle: 'buns', style: 'overalls', shirt: 0xe3b23c, boots: 0x8a2f24, hat: 'none', accessory: 'scarf' },
  moody: { skin: 0x7a4b30, hair: 0xd06a8a, hairStyle: 'long', style: 'raincoat', shirt: 0x4a5568, boots: 0x1e1a16, hat: 'bucket', accessory: 'satchel' },
};
for (const [name, o] of Object.entries(PRESETS)) {
  await page.evaluate((oo) => { const G = window.__BY_G; G.setOutfit(oo); G.styleActive = true; }, o);
  await page.waitForTimeout(4500); // style cam glide + a bit of rotation
  await page.screenshot({ path: `${prefix}-${name}-a.png` });
  await page.waitForTimeout(2600); // character keeps rotating -> second angle
  await page.screenshot({ path: `${prefix}-${name}-b.png` });
}
await page.evaluate(() => { window.__BY_G.styleActive = false; });
await page.waitForTimeout(2000);
// gameplay: walking shot — wait for the stride to approach a swing extreme
// (sin rising through 0.7 at 11 rad/s) so screenshot latency lands the
// frame near peak arm swing instead of a random dead-center pose
await page.keyboard.down('d');
await page.waitForTimeout(700);
await page.waitForFunction(() => {
  const t = window.__BY_G.time * 11;
  return Math.sin(t) > 0.7 && Math.cos(t) > 0;
}, null, { timeout: 4000 }).catch(() => {});
await page.screenshot({ path: `${prefix}-walk.png` });
await page.keyboard.up('d');
// portrait medallion (actual offscreen render the HUD uses)
await page.waitForTimeout(1200);
const dataUrl = await page.evaluate(() => {
  const img = [...document.querySelectorAll('img')].find((i) => (i.src || '').startsWith('data:image') && i.getBoundingClientRect().top < 120);
  return img ? img.src : null;
});
if (dataUrl) fs.writeFileSync(`${prefix}-portrait.png`, Buffer.from(dataUrl.split(',')[1], 'base64'));
console.log('wrote shots with prefix', prefix, '| portrait:', !!dataUrl);
await b.close();
