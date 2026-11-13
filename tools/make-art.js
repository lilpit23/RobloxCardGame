// Renders the game's image assets (icon, thumbnail, pack covers) into assets/.
// Run: node tools/make-art.js   (needs Playwright with Chromium)
const { chromium } = require('playwright');
const path = require('path');
const out = path.join(__dirname, '..', 'assets');

const SETS = [
  ['storybook', 'Storybook Friends', '本', '#eba83c'],
  ['seas', 'High Seas', '海', '#3c82d7'],
  ['west', 'Journey to the West', '西', '#e14b41'],
  ['midnight', 'Midnight Classics', '夜', '#8250c8'],
  ['olympus', 'Olympus', '神', '#3cbeaa'],
  ['knights', 'Knights and Outlaws', '騎', '#32965a'],
  ['rome', 'Glory of Rome', '羅', '#aa232d'],
  ['america', 'Pax Americana', '鷲', '#2d50a5'],
  ['norse', 'Norse Sagas', '北', '#468296'],
];
// One Booster and one (darker) Elite cover per set, plus the Champion Pack.
const PACKS = [];
for (const [id, name, kanji, color] of SETS) {
  PACKS.push([id + '_booster', name + ' Booster', kanji, color, 5]);
  PACKS.push([id + '_elite', name + ' Elite', kanji, `color-mix(in srgb, ${color} 62%, #000)`, 5]);
}
PACKS.push(['champion', 'Champion Pack', '王', '#cfd3e6', 5]);

const base = `
  * { box-sizing: border-box; margin: 0; }
  html, body { width: 100%; height: 100%; overflow: hidden; }
  body { font-family: 'Inter Display', 'Inter', sans-serif; background: #0d0718; position: relative; }
  .bg { position: absolute; inset: 0;
    background:
      radial-gradient(circle at 50% 45%, rgba(255,90,170,.55), rgba(120,60,230,.35) 35%, rgba(13,7,24,0) 70%),
      repeating-conic-gradient(from 0deg at 50% 45%, rgba(255,255,255,.07) 0 6deg, rgba(255,255,255,0) 6deg 14deg),
      linear-gradient(160deg, #2a0f52, #0d0718 70%); }
  .card { position: absolute; border-radius: 7%/5%; border: .5em solid #15101f;
    box-shadow: 0 1.2em 2.5em rgba(0,0,0,.6), inset 0 0 0 .25em rgba(255,255,255,.55);
    display: flex; flex-direction: column; align-items: center; justify-content: center; overflow: hidden; }
  .card::after { content: ''; position: absolute; inset: 0;
    background: linear-gradient(115deg, rgba(255,255,255,0) 35%, rgba(255,255,255,.45) 48%, rgba(255,255,255,0) 60%); }
  .kanji { font-family: 'IPAGothic', sans-serif; font-weight: 700; color: #fff; line-height: 1;
    text-shadow: 0 0 .25em rgba(255,255,255,.9), 0 .06em 0 rgba(0,0,0,.35); }
  .stars { color: #fff; letter-spacing: .15em; margin-top: .4em; text-shadow: 0 .08em 0 rgba(0,0,0,.35); }
  .rare { background: linear-gradient(170deg, #6fb1ff, #2a55c9); }
  .epic { background: linear-gradient(170deg, #cf8bff, #6a26c4); }
  .legend { background: linear-gradient(170deg, #ffe07a, #f0871e); }
  .title { position: absolute; font-weight: 900; font-style: italic; line-height: .86; text-align: center;
    letter-spacing: -.02em; text-transform: uppercase;
    background: linear-gradient(180deg, #fff6c2 10%, #ffc83d 45%, #ff5fa8 95%);
    -webkit-background-clip: text; background-clip: text; color: transparent;
    -webkit-text-stroke: .045em #1a0b2e; paint-order: stroke fill;
    filter: drop-shadow(0 .07em 0 #1a0b2e) drop-shadow(0 .16em .25em rgba(0,0,0,.6)); }
`;

function fan(fontPx) {
  const card = (cls, kanji, stars, style) =>
    `<div class="card ${cls}" style="${style}"><div class="kanji">${kanji}</div><div class="stars">${'★'.repeat(stars)}</div></div>`;
  return `<div class="fan" style="font-size:${fontPx}px">
    ${card('rare', '剣', 3, 'width:9em;height:12.6em;left:-11.5em;top:1.2em;transform:rotate(-16deg);')}
    ${card('legend', '龍', 5, 'width:9em;height:12.6em;left:2.5em;top:1.2em;transform:rotate(16deg);')}
    ${card('epic', '気', 4, 'width:10em;height:14em;left:-5em;top:-1em;z-index:2;')}
  </div>`;
}

const icon = `<style>${base}
  .fan { position: absolute; left: 50%; top: 40px; }
  .fan .kanji { font-size: 5.6em; } .fan .stars { font-size: 1.1em; }
  .title { left: 0; right: 0; bottom: 22px; font-size: 104px; }
</style><div class="bg"></div>${fan(22)}<div class="title">Aura<br>Packs</div>`;

const thumb = `<style>${base}
  .fan { position: absolute; left: 77%; top: 230px; }
  .fan .kanji { font-size: 5.6em; } .fan .stars { font-size: 1.1em; }
  .title { left: 110px; top: 210px; font-size: 250px; text-align: left; }
  .tag { position: absolute; left: 124px; top: 690px; width: 800px; line-height: 1.15; color: #fff; font-weight: 800; font-size: 54px;
    text-shadow: 0 4px 0 #1a0b2e, 0 8px 18px rgba(0,0,0,.6); }
  .chips { position: absolute; left: 124px; top: 880px; display: flex; gap: 22px; }
  .chip { font-weight: 800; font-size: 38px; color: #1a0b2e; padding: 14px 30px; border-radius: 999px; background: #ffd24d; }
  .chip:nth-child(2) { background: #ff7ac0; } .chip:nth-child(3) { background: #7fd6ff; }
</style><div class="bg" style="background-position: 30% 0"></div>${fan(38)}
<div class="title">Aura<br>Packs</div><div class="tag">Open packs. Build your store. Collect them all.</div>
<div class="chips"><div class="chip">9 sets · 333 cards</div><div class="chip">Rebirths</div><div class="chip">Battle Tower</div></div>`;

const pack = (name, kanji, color, count) => `<style>${base}
  body { background: transparent; }
  .pack { position: absolute; inset: 18px 36px; border-radius: 14px; overflow: hidden;
    background: linear-gradient(160deg, color-mix(in srgb, ${color} 70%, #fff), ${color} 40%, color-mix(in srgb, ${color} 55%, #000));
    box-shadow: inset 0 0 0 5px rgba(255,255,255,.35), inset 0 0 60px rgba(0,0,0,.35); }
  .crimp { position: absolute; left: 0; right: 0; height: 44px;
    background: repeating-linear-gradient(90deg, rgba(255,255,255,.4) 0 6px, rgba(0,0,0,.22) 6px 12px); }
  .crimp.top { top: 0; } .crimp.bottom { bottom: 0; }
  .shine { position: absolute; inset: 0; background: linear-gradient(115deg, rgba(255,255,255,0) 30%, rgba(255,255,255,.4) 46%, rgba(255,255,255,0) 58%); }
  .seal { position: absolute; left: 50%; top: 150px; width: 260px; height: 260px; margin-left: -130px; border-radius: 50%;
    background: rgba(20,10,35,.82); border: 8px solid rgba(255,255,255,.85); display: flex; align-items: center; justify-content: center; }
  .seal .kanji { font-size: 170px; }
  .name { position: absolute; left: 0; right: 0; top: 430px; text-align: center; font-weight: 900; font-style: italic; font-size: 40px;
    line-height: 1; text-transform: uppercase; color: #fff; -webkit-text-stroke: 3px #1a0b2e; paint-order: stroke fill;
    filter: drop-shadow(0 4px 0 #1a0b2e); padding: 0 20px; }
  .count { position: absolute; left: 0; right: 0; bottom: 70px; text-align: center; font-weight: 800; font-size: 30px; color: rgba(20,10,35,.85); letter-spacing: .12em; }
</style><div class="pack"><div class="crimp top"></div><div class="crimp bottom"></div>
<div class="seal"><div class="kanji">${kanji}</div></div><div class="name">${name.replace(/ (Booster|Elite|Pack)$/, '<br>$1').replace(' to the ', ' to<br>the ').replace(' and ', ' and<br>').replace(' of ', ' of<br>')}</div>
<div class="count">${count} CARDS</div><div class="shine"></div></div>`;

(async () => {
  const browser = await chromium.launch();
  const shot = async (html, width, height, file, transparent) => {
    const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
    await page.setContent(`<!doctype html><meta charset="utf-8">${html}`);
    await page.screenshot({ path: path.join(out, file), omitBackground: !!transparent });
    await page.close();
  };
  await shot(icon, 512, 512, 'icon.png');
  await shot(thumb, 1920, 1080, 'thumbnail.png');
  for (const [id, name, kanji, color, count] of PACKS) await shot(pack(name, kanji, color, count), 512, 716, `packs/${id}.png`, true);
  await browser.close();
})();
