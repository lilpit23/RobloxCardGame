// Draws a top-down diagram of the map (docs/map-layout.png) from the same numbers Plots.luau uses.
// Run: node tools/make-map.js
const { chromium } = require('playwright');
const path = require('path');
const N = 8, HALF = 32, ROAD_W = 24, ROAD_LEN = 150, TUN_LEN = 70, TUN_W = 32, ARENA_R = 85;
const step = (2 * Math.PI) / (N + 1);
const R = Math.ceil(HALF / Math.tan(step / 2)) + 6, D = R + HALF;
const tunStart = R + ROAD_LEN, tunEnd = tunStart + TUN_LEN, arenaX = tunEnd + ARENA_R + 10, towerX = arenaX + 38;
const minX = -(D + HALF + 30), maxX = arenaX + ARENA_R + 30, half = 215;
let s = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${minX} ${-half} ${maxX - minX} ${half * 2}" width="1600" height="${Math.round(1600 * half * 2 / (maxX - minX))}" font-family="Inter, sans-serif">`;
s += `<rect x="${minX}" y="${-half}" width="${maxX - minX}" height="${half * 2}" fill="#5faa69"/>`;
s += `<rect x="${R - 2}" y="${-ROAD_W / 2}" width="${arenaX - ARENA_R + 4 - (R - 2)}" height="${ROAD_W}" fill="#34363c"/>`;
s += `<circle r="${R + 5}" fill="#bebec3"/><circle r="${R}" fill="#34363c"/><circle r="24" fill="#bebec3"/><circle r="22" fill="#5faa69"/>`;
for (const side of [-1, 1]) s += `<rect x="${tunStart}" y="${side > 0 ? TUN_W / 2 : -TUN_W / 2 - 150}" width="${TUN_LEN}" height="150" fill="#69625c"/>`;
s += `<rect x="${tunStart}" y="${-TUN_W / 2}" width="${TUN_LEN}" height="${TUN_W}" fill="#3b3640"/>`;
s += `<circle cx="${arenaX}" r="${ARENA_R + 4}" fill="#69625c"/><circle cx="${arenaX}" r="${ARENA_R}" fill="#3c3a46"/>`;
s += `<rect x="${tunEnd}" y="-6" width="${towerX - 19 - tunEnd}" height="12" fill="#968c7d"/>`;
s += `<rect x="${towerX - 18}" y="-18" width="36" height="36" fill="#aa5af0" stroke="#1a0b2e" stroke-width="2"/>`;
for (const side of [-1, 1]) s += `<rect x="${arenaX - 20}" y="${side * (ARENA_R - 8) - 2}" width="20" height="4" fill="#dc3246"/>`;
for (let i = 1; i <= N; i++) {
  const a = i * step, deg = (a * 180) / Math.PI;
  s += `<g transform="translate(${D * Math.cos(a)} ${D * Math.sin(a)}) rotate(${deg + 90})"><rect x="${-HALF}" y="${-HALF}" width="${HALF * 2}" height="${HALF * 2}" rx="3" fill="#c79a6b" stroke="#1a0b2e" stroke-width="2"/><rect x="-10" y="${HALF - 9}" width="20" height="5" fill="#46dc6e"/></g>`;
  s += `<text x="${D * Math.cos(a)}" y="${D * Math.sin(a) + 6}" text-anchor="middle" font-size="18" font-weight="800" fill="#1a0b2e">Store ${i}</text>`;
}
const label = (x, y, t, size = 15, fill = '#fff') => `<text x="${x}" y="${y}" text-anchor="middle" font-size="${size}" font-weight="800" fill="${fill}" stroke="#1a0b2e" stroke-width="3" paint-order="stroke">${t}</text>`;
s += label(0, 5, 'Spawn', 13) + label(0, -40, 'Cul-de-sac plaza', 15) + label((R + tunStart) / 2, -20, 'Road', 15);
s += label((tunStart + tunEnd) / 2, 5, 'Tunnel', 14) + label((tunStart + tunEnd) / 2, -100, 'Ridge', 15) + label((tunStart + tunEnd) / 2, 105, 'Ridge', 15);
s += label(arenaX - 20, -30, 'PvE arena', 16) + label(towerX, 34, 'Tower', 14) + label(arenaX - 10, -ARENA_R + 26, 'Monster gate', 11) + label(arenaX - 10, ARENA_R - 16, 'Monster gate', 11);
s += `</svg>`;
(async () => {
  const browser = await chromium.launch();
  const h = Math.round(1600 * half * 2 / (maxX - minX));
  const page = await browser.newPage({ viewport: { width: 1600, height: h }, deviceScaleFactor: 1 });
  await page.setContent(`<!doctype html><meta charset="utf-8"><body style="margin:0">${s}</body>`);
  await page.screenshot({ path: path.join(__dirname, '..', 'docs', 'map-layout.png') });
  await browser.close();
})();
