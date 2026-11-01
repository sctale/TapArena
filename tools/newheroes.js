const path = require('path');
const { launch, shotsDir, url } = require('./harness');
const HEROES = ['tiger', 'fox', 'rabbit', 'bear', 'otter', 'hedgehog'];
(async () => {
  const out = shotsDir('new');
  const browser = await launch();
  const errors = [];
  /* 选人页：桌面 + 手机横屏 */
  for (const vp of [{ name: 'select-desktop', w: 1440, h: 900 }, { name: 'select-phone', w: 900, h: 430 }]) {
    const page = await browser.newPage({ viewport: { width: vp.w, height: vp.h }, deviceScaleFactor: 1 });
    page.on('pageerror', e => errors.push(vp.name + ': ' + e.message));
    await page.goto(url);
    await page.waitForTimeout(900);
    await page.click('#btnStart');
    await page.waitForTimeout(700);
    await page.screenshot({ path: path.join(out, vp.name + '.png') });
    const box = await page.evaluate(() => {
      const cards = Array.from(document.querySelectorAll('.hero-card')).map(c => {
        const b = c.getBoundingClientRect();
        return { hero: c.dataset.hero, w: Math.round(b.width), h: Math.round(b.height), overflow: c.scrollHeight > c.clientHeight + 1 };
      });
      const go = document.querySelector('#btnGo').getBoundingClientRect();
      return { cards, goVisible: go.bottom <= innerHeight + 1 && go.top >= 0, vw: innerWidth, vh: innerHeight };
    });
    console.log(vp.name, JSON.stringify(box));
    await page.close();
  }
  /* 六位英雄的战斗特写 */
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => errors.push('battle: ' + e.message));
  for (const hero of HEROES) {
    await page.goto(url + '?auto=1&hero=' + hero);
    await page.waitForFunction(() => window.__TA && window.__TA.state().screen === 'battle', null, { timeout: 15000 });
    await page.evaluate(() => window.__TA.skipCountdown());
    await page.waitForTimeout(600);
    await page.evaluate(() => window.__TA.stage(true));
    await page.waitForTimeout(300);
    await page.evaluate(() => window.__TA.still(true));
    for (const [kind, p] of [['idle', 0.3], ['attack', 0.5], ['cast', 0.5], ['hurt', 0.35]]) {
      await page.evaluate(([k, v]) => window.__TA.pose(k, v), [kind, p]);
      await page.waitForTimeout(70);
      await page.screenshot({ path: path.join(out, `pose-${hero}-${kind}.png`), clip: { x: 700, y: 330, width: 520, height: 400 } });
    }
    await page.evaluate(() => window.__TA.still(false));
    console.log('posed', hero);
  }
  console.log(errors.length ? 'ERRORS:\n' + errors.join('\n') : 'NO_PAGE_ERRORS');
  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
