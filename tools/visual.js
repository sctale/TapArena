const path = require('path');
const { launch, shotsDir, url } = require('./harness');

(async () => {
  const out = shotsDir('after');
  const browser = await launch();
  const errors = [];
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => { if (/Framebuffer status/.test(e.message)) return; errors.push(e.message); console.log('PAGEERROR:', e.message); });
  page.on('console', m => { if (m.type() === 'error') { errors.push(m.text()); console.log('CONSOLE:', m.text()); } });

  const heroes = ['tiger', 'fox', 'rabbit'];
  for (const hero of heroes) {
    await page.goto(url + '?auto=1&hero=' + hero);
    await page.waitForFunction(() => window.__TA && window.__TA.state().screen === 'battle', null, { timeout: 15000 });
    await page.evaluate(() => window.__TA.skipCountdown());
    await page.waitForTimeout(700);
    await page.evaluate(() => window.__TA.stage(true));
    await page.waitForTimeout(500);
    await page.screenshot({ path: path.join(out, `battle-${hero}-idle.png`) });

    /* 定格在动作中段再截，避免截图延迟错过 0.22s 的挥击 */
    await page.evaluate(() => window.__TA.still(true));
    const frames = [
      ['attack', 0.5],
      ['cast', 0.55],
      ['hurt', 0.4]
    ];
    if (hero === 'tiger') frames.push(['spin', 0.35]);
    frames.push(['death', 0.35]);
    for (const [kind, p] of frames) {
      await page.evaluate(([k, v]) => window.__TA.pose(k, v), [kind, p]);
      await page.waitForTimeout(90);
      await page.screenshot({ path: path.join(out, `battle-${hero}-${kind}.png`) });
    }
    await page.evaluate(() => window.__TA.still(false));
    console.log('captured', hero);
  }

  /* 动态混战 + 帧率 */
  await page.goto(url + '?auto=1&hero=tiger');
  await page.waitForFunction(() => window.__TA && window.__TA.state().screen === 'battle', null, { timeout: 15000 });
  await page.evaluate(() => window.__TA.skipCountdown());
  await page.waitForTimeout(700);
  await page.evaluate(() => window.__TA.stage(false));
  await page.waitForTimeout(800);
  const fps = await page.evaluate(() => new Promise(res => {
    let frames = 0;
    const t0 = performance.now();
    function step(t) {
      frames++;
      if (t - t0 < 4000) requestAnimationFrame(step);
      else res(+(frames / ((t - t0) / 1000)).toFixed(1));
    }
    requestAnimationFrame(step);
  }));
  await page.screenshot({ path: path.join(out, 'battle-melee.png') });
  console.log('FPS:', fps);
  console.log(errors.length ? 'ERRORS:\n' + errors.join('\n') : 'NO_PAGE_ERRORS');
  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
