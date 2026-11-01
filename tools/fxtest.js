const path = require('path');
const { launch, shotsDir, url } = require('./harness');
(async () => {
  const out = shotsDir('new');
  const browser = await launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1 });
  const errors = [];
  page.on('pageerror', e => { if (/Framebuffer status/.test(e.message)) return; errors.push(e.message); });
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(m.type() + ': ' + m.text()); });
  await page.goto(url + '?auto=1&hero=bear');
  await page.waitForFunction(() => window.__TA && window.__TA.state().screen === 'battle', null, { timeout: 15000 });
  await page.evaluate(() => window.__TA.skipCountdown());
  await page.waitForTimeout(1200);
  await page.evaluate(() => window.__TA.stage(false));
  await page.waitForTimeout(6000);
  const info = await page.evaluate(() => ({
    phaser: typeof Phaser !== 'undefined' ? Phaser.VERSION : 'missing',
    ready: window.StageFX && StageFX.ready,
    renderer: window.StageFX && StageFX.game ? StageFX.game.renderer.type : null,
    gl: !!(window.StageFX && StageFX.game && StageFX.game.renderer && StageFX.game.renderer.gl),
    div: !!document.querySelector('#fxStage canvas'),
    view: window.__FX_VIEW ? window.__FX_VIEW() : null
  }));
  console.log('FX', JSON.stringify(info));
  const fps = await page.evaluate(() => new Promise(res => {
    let f = 0; const t0 = performance.now();
    (function step(t) { f++; if (t - t0 < 4000) requestAnimationFrame(step); else res(+(f / ((t - t0) / 1000)).toFixed(1)); })(performance.now());
  }));
  console.log('FPS', fps);
  await page.screenshot({ path: path.join(out, 'fx-battle.png') });
  console.log(errors.length ? 'LOG:\n' + errors.slice(0, 8).join('\n') : 'NO_CONSOLE_ERRORS');
  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
