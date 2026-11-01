const path = require('path');
const { launch, shotsDir, url } = require('./harness');
(async () => {
  const out = shotsDir('preview');
  const browser = await launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => { if (/Framebuffer status/.test(e.message)) return; console.log('PAGEERROR:', e.message); });
  await page.goto(url);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: path.join(out, 'pv-home.png') });
  await page.click('#btnStart');
  await page.waitForTimeout(900);
  await page.screenshot({ path: path.join(out, 'pv-select.png') });
  await page.click('.hero-card[data-hero="bear"]');
  await page.waitForTimeout(400);
  await page.click('#btnGo');
  await page.waitForFunction(() => window.__TA && window.__TA.state().screen === 'battle', null, { timeout: 15000 });
  await page.evaluate(() => window.__TA.skipCountdown());
  await page.waitForTimeout(600);
  await page.evaluate(() => window.__TA.stage(false));
  let best = null;
  for (let i = 0; i < 10; i++) {
    await page.waitForTimeout(2500);
    const s = await page.evaluate(() => window.__TA.state());
    if (!best || s.effects > best.effects) best = s;
    await page.screenshot({ path: path.join(out, `pv-battle-${i}.png`) });
  }
  console.log('best fx', best && best.effects, 'time', best && best.time);
  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
