const path = require('path');
const { launch, shotsDir, url } = require('./harness');

(async () => {
  const out = shotsDir('ui');
  const browser = await launch();
  const errors = [];
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  page.on('pageerror', e => { errors.push(e.message); console.log('PAGEERROR:', e.message); });
  page.on('console', m => { if (m.type() === 'error') { errors.push(m.text()); console.log('CONSOLE:', m.text()); } });

  await page.goto(url);
  await page.waitForTimeout(1300);
  await page.screenshot({ path: path.join(out, '01-home-desktop.png') });

  await page.click('#btnStart');
  await page.waitForTimeout(700);
  await page.screenshot({ path: path.join(out, '02-select-tiger.png') });

  await page.click('.hero-card[data-hero="fox"]');
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(out, '03-select-fox.png') });

  await page.click('#btnGo');
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(out, '04-countdown.png') });

  await page.evaluate(() => window.__TA.skipCountdown());
  await page.waitForTimeout(1400);
  await page.screenshot({ path: path.join(out, '05-battle-early.png') });

  // move forward and fire skills
  await page.keyboard.down('d');
  await page.waitForTimeout(1600);
  await page.keyboard.up('d');
  await page.keyboard.press('q');
  await page.waitForTimeout(900);
  await page.keyboard.press('w');
  await page.waitForTimeout(900);
  await page.screenshot({ path: path.join(out, '06-battle-fight.png') });

  const state = await page.evaluate(() => window.__TA.state());
  console.log('STATE:', JSON.stringify(state));

  // simulate a full AI match
  const sim = await page.evaluate(() => window.__TA.simulate(900));
  console.log('SIM:', JSON.stringify(sim));

  const layout = await page.evaluate(() => {
    const q = s => document.querySelector(s);
    const rect = el => { if (!el) return null; const r = el.getBoundingClientRect(); return { w: Math.round(r.width), h: Math.round(r.height), top: Math.round(r.top), left: Math.round(r.left), bottom: Math.round(r.bottom) }; };
    return {
      doc: { w: innerWidth, h: innerHeight, sw: document.documentElement.scrollWidth, sh: document.documentElement.scrollHeight },
      homeContent: rect(q('.home-content')),
      skillDock: rect(q('.skill-dock')),
      hudTop: rect(q('.hud-top')),
      minimap: rect(q('.minimap-wrap')),
      card: rect(q('.hero-card')),
      detail: rect(q('.hero-detail'))
    };
  });
  console.log('LAYOUT:', JSON.stringify(layout));

  await page.evaluate(() => window.__TA.finish('blue'));
  await page.waitForTimeout(2600);
  await page.screenshot({ path: path.join(out, '07-result-win.png') });

  await ctx.close();
  await browser.close();
  console.log(errors.length ? 'ERRORS:\n' + errors.join('\n') : 'NO_PAGE_ERRORS');
})().catch(e => { console.error('FATAL', e); process.exit(1); });
