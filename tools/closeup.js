const path = require('path');
const { launch, shotsDir, url } = require('./harness');

(async () => {
  const out = shotsDir('after');
  const browser = await launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  const clip = { x: 680, y: 330, width: 560, height: 430 };
  for (const hero of ['tiger', 'fox', 'rabbit']) {
    await page.goto(url + '?auto=1&hero=' + hero);
    await page.waitForFunction(() => window.__TA && window.__TA.state().screen === 'battle', null, { timeout: 15000 });
    await page.evaluate(() => window.__TA.skipCountdown());
    await page.waitForTimeout(600);
    await page.evaluate(() => window.__TA.stage(true));
    await page.waitForTimeout(300);
    await page.evaluate(() => window.__TA.still(true));
    for (const [kind, p] of [['attack', 0.5], ['cast', 0.55], ['hurt', 0.4]]) {
      await page.evaluate(([k, v]) => window.__TA.pose(k, v), [kind, p]);
      await page.waitForTimeout(80);
      await page.screenshot({ path: path.join(out, `close-${hero}-${kind}.png`), clip });
    }
    console.log('close', hero);
  }
  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
