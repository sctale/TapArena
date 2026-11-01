const path = require('path');
const { launch, shotsDir, url } = require('./harness');
(async () => {
  const out = shotsDir('scene');
  const browser = await launch();
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  page.on('pageerror', e => console.log('PAGEERROR:', e.message));
  await page.goto(url + '?auto=1&hero=tiger');
  await page.waitForTimeout(5000); // countdown
  await page.screenshot({ path: path.join(out, 's01-start.png') });
  await page.waitForTimeout(9000);
  await page.screenshot({ path: path.join(out, 's02-first-fight.png') });
  await page.evaluate(() => window.__TA.setPlayerPos(1330, 900));
  await page.waitForTimeout(1400);
  await page.screenshot({ path: path.join(out, 's03-bridge.png') });
  await page.evaluate(() => window.__TA.setPlayerPos(1840, 1000));
  await page.waitForTimeout(1400);
  await page.screenshot({ path: path.join(out, 's04-enemy-tower.png') });
  await page.evaluate(() => { window.__TA.setPlayerPos(330, 1010); });
  await page.waitForTimeout(1200);
  await page.screenshot({ path: path.join(out, 's05-base.png') });
  const st = await page.evaluate(() => window.__TA.state());
  console.log('STATE', JSON.stringify(st));
  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
