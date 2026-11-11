// Draws a front-view sketch of the store building at every tier (docs/store-tiers.png),
// using the same sizes as buildDecor in src/server/Plots.luau. Run: node tools/make-buildings.js
const { chromium } = require('playwright');
const path = require('path');
const HALF = 32, GROUND = 16, STOREY = 14, INSET = 2;
const NAMES = ['Card Stall', 'Card Shop', 'Card Emporium', 'Mega Card Store', 'Aura Tower', 'Card Palace', 'Hall of Legends'];
const WALL = [null, '#eedebe', '#e1cdb9', '#cdd7e6', '#5a5578', '#f0eee8', '#282440'];
const TRIM = [null, '#785032', '#6e4637', '#37415a', '#2d2846', '#d7aa46', '#141222'];
const ACCENT = ['#e6c896', '#50aaff', '#aa5af0', '#ff50aa', '#fff096', '#78ffff', '#ff78ff'];
const W = 1900, H = 620, GAP = 270, GROUNDY = 520, S = 3.1; // S = pixels per stud
let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" font-family="Inter, sans-serif"><rect width="${W}" height="${H}" fill="#8fd0f5"/><rect y="${GROUNDY}" width="${W}" height="${H - GROUNDY}" fill="#5faa69"/>`;
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" ${extra}/>`;
for (let tier = 1; tier <= 7; tier++) {
  const cx = 140 + (tier - 1) * GAP;
  const X = (studs) => cx + studs * S, Y = (studs) => GROUNDY - studs * S;
  if (tier === 1) {
    for (const sx of [-1, 1]) s += rect(X(sx * 30) - 2, Y(11), 4, 11 * S, '#785537');
    for (let i = 0; i < 8; i++) s += rect(X(-32 + i * 8), Y(11.5), 8 * S, 1.5 * S, i % 2 ? '#f5f5f5' : '#dc4646');
    for (let i = 0; i < 4; i++) s += rect(X(-24 + i * 14), Y(7), 4 * S, 5.6 * S, '#aa5af0', 'rx="2" stroke="#1a0b2e"');
  } else {
    const wall = WALL[tier - 1], trim = TRIM[tier - 1], accent = ACCENT[tier - 1];
    s += rect(X(-HALF), Y(1 + GROUND), HALF * 2 * S, (GROUND) * S, wall, 'stroke="#1a0b2e"');
    s += rect(X(-HALF + 2), Y(GROUND - 1), (HALF * 2 - 4) * S, (GROUND - 2) * S, '#2a2438'); // open shopfront
    for (let i = 0; i < 6; i++) s += rect(X(-25 + i * 9), Y(7.5), 4 * S, 5.6 * S, '#aa5af0', 'rx="2"');
    for (const sx of [-1, 1]) s += rect(X(sx * 31) - S, Y(1 + GROUND), 2 * S, GROUND * S, trim);
    for (let i = 0; i < 8; i++) s += rect(X(-32 + i * 8), Y(GROUND + 2), 8 * S, 1.2 * S, i % 2 ? '#f5f5f5' : accent);
    let roofY = GROUND + 2, half = HALF;
    for (let k = 1; k <= tier - 2; k++) {
      half = HALF - INSET * k;
      s += rect(X(-half), Y(roofY + STOREY), half * 2 * S, STOREY * S, wall, 'stroke="#1a0b2e"');
      s += rect(X(-half - 0.75), Y(roofY + 0.8), (half * 2 + 1.5) * S, 0.8 * S, trim);
      [-0.6, -0.2, 0.2, 0.6].forEach((share, i) => { s += rect(X(share * half - 3), Y(roofY + 9.5), 6 * S, 6 * S, (k + i + 1) % 2 === 0 ? '#ffe8a0' : '#96c3eb', 'stroke="#1a0b2e"'); });
      roofY += STOREY;
    }
    if (tier <= 3) {
      for (let step = 0; step < 5; step++) s += rect(X(-(half + 1) * (1 - step / 5)), Y(roofY + 2 + step * 2), (half * 2 + 2) * (1 - step / 5) * S, 2 * S, '#963c37');
    } else {
      s += rect(X(-half), Y(roofY + 2), half * 2 * S, 2 * S, trim);
      s += rect(X(-12), Y(roofY + 12), 24 * S, 6 * S, accent, 'rx="3" stroke="#1a0b2e"');
      if (tier >= 5) s += rect(X(-2), 0, 4 * S, Y(roofY + 2), accent, 'opacity="0.45"');
      if (tier >= 6) s += `<circle cx="${X(0)}" cy="${Y(roofY + 2)}" r="${12 * S}" fill="#f5c850" stroke="#1a0b2e"/>` + rect(X(-half), Y(roofY + 2), half * 2 * S, 2 * S, trim);
      if (tier >= 7) { for (const sx of [-1, 1]) s += `<rect x="${X(sx * (half - 1)) - 5}" y="${Y(roofY + 16)}" width="10" height="22" fill="${accent}" transform="rotate(45 ${X(sx * (half - 1))} ${Y(roofY + 12)})"/>`; s += rect(X(-18), Y(roofY + 30.5), 36 * S, S, accent); }
    }
  }
  s += `<text x="${cx}" y="${GROUNDY + 40}" text-anchor="middle" font-size="24" font-weight="800" fill="#1a0b2e">${tier}. ${NAMES[tier - 1]}</text>`;
  s += `<text x="${cx}" y="${GROUNDY + 68}" text-anchor="middle" font-size="17" fill="#1a0b2e">${tier === 1 ? 'open stall' : tier === 2 ? '1 storey' : (tier - 1) + ' storeys'}</text>`;
}
s += '</svg>';
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  await page.setContent(`<!doctype html><meta charset="utf-8"><body style="margin:0">${s}</body>`);
  await page.screenshot({ path: path.join(__dirname, '..', 'docs', 'store-tiers.png') });
  await browser.close();
})();
