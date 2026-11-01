const path = require('path');
const { launch, shotsDir, url } = require('./harness');
(async () => {
  const out = shotsDir('new');
  const browser = await launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  await page.goto(url + '?auto=1&hero=tiger');
  await page.waitForFunction(() => window.__TA && window.__TA.state().screen === 'battle', null, { timeout: 20000 });
  await page.evaluate(() => window.__TA.skipCountdown());
  await page.waitForTimeout(1000);
  await page.evaluate(() => window.__TA.stage(true));
  await page.waitForTimeout(500);
  await page.evaluate(() => window.__TA.still(true));
  const frames = [[0, 0.2], [1, 0.45], [2, 0.55], [3, 0.85]];
  for (const [i, pv] of frames) {
    await page.evaluate(v => window.__TA.pose('attack', v), pv);
    await page.waitForTimeout(130);
    await page.screenshot({ path: path.join(out, '3d-atk-' + i + '.png'), clip: { x: 330, y: 250, width: 620, height: 420 } });
  }
  console.log('captured', frames.length, 'attack frames');
  await browser.close();
})().catch(e => { console.error('FATAL', e.message); process.exit(1); });
