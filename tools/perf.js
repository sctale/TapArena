const { launch, url } = require('./harness');

(async () => {
  const browser = await launch();
  for (const cfg of [
    { name: 'desktop', w: 1920, h: 1080, rate: 4 },
    { name: 'phone', w: 900, h: 430, rate: 4 },
    { name: 'phone-cpu6', w: 900, h: 430, rate: 6 }
  ]) {
    const page = await browser.newPage({ viewport: { width: cfg.w, height: cfg.h }, deviceScaleFactor: 1 });
    const errors = [];
    page.on('pageerror', e => { if (/Framebuffer status/.test(e.message)) return; errors.push(e.message); });
    const cdp = await page.context().newCDPSession(page);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: cfg.rate });
    await page.goto(url + '?auto=1&hero=tiger');
    await page.waitForFunction(() => window.__TA && window.__TA.state().screen === 'battle', null, { timeout: 20000 });
    await page.evaluate(() => window.__TA.skipCountdown());
    await page.waitForTimeout(1500);
    await page.evaluate(() => window.__TA.stage(false));
    await page.waitForTimeout(8000);
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
    console.log(cfg.name, 'cpu-x' + cfg.rate, 'fps=' + fps, 'errors=' + errors.length);
    await page.close();
  }
  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
