const path = require('path');
const { launch, shotsDir, url } = require('./harness');

(async () => {
  const out = shotsDir('mobile');
  const browser = await launch();
  const errors = [];
  const results = {};

  // ---- phone landscape with touch ----
  const ctx = await browser.newContext({ viewport: { width: 900, height: 430 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const page = await ctx.newPage();
  page.on('pageerror', e => { if (/Framebuffer status/.test(e.message)) return; errors.push('landscape: ' + e.message); console.log('PAGEERROR:', e.message); });
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(url);
  await page.waitForTimeout(1100);
  await page.screenshot({ path: path.join(out, 'm01-home.png') });
  await page.tap('#btnStart');
  await page.waitForTimeout(600);
  await page.screenshot({ path: path.join(out, 'm02-select.png') });
  results.selectMetrics = await page.evaluate(() => {
    const r = s => { const el = document.querySelector(s); if (!el) return null; const b = el.getBoundingClientRect(); return { x: Math.round(b.x), y: Math.round(b.y), w: Math.round(b.width), h: Math.round(b.height), bottom: Math.round(b.bottom) }; };
    return { vw: innerWidth, vh: innerHeight, card: r('.hero-card'), detail: r('.hero-detail'), go: r('#btnGo'), head: r('.select-head'), bodyOverflow: document.querySelector('.select-body').scrollHeight };
  });
  await page.tap('#btnGo');
  await page.waitForTimeout(600);
  await page.evaluate(() => window.__TA.skipCountdown());
  await page.waitForTimeout(1600);
  await page.screenshot({ path: path.join(out, 'm03-battle.png') });
  await page.keyboard.down('d');
  await page.waitForTimeout(1200);
  await page.keyboard.up('d');
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(out, 'm04-battle-move.png') });
  results.battleMetrics = await page.evaluate(() => {
    const r = s => { const el = document.querySelector(s); if (!el) return null; const b = el.getBoundingClientRect(); return { x: Math.round(b.x), y: Math.round(b.y), w: Math.round(b.width), h: Math.round(b.height), bottom: Math.round(b.bottom) }; };
    const btns = Array.from(document.querySelectorAll('.skill-btn')).map(el => { const b = el.getBoundingClientRect(); return { x: Math.round(b.x), y: Math.round(b.y), w: Math.round(b.width), h: Math.round(b.height), bottom: Math.round(b.bottom), right: Math.round(b.right) }; });
    return { vw: innerWidth, vh: innerHeight, hud: r('.hud-top'), minimap: r('.minimap-wrap'), dock: r('.skill-dock'), btns, hint: r('.joystick-hint'), rotateDisplay: getComputedStyle(document.querySelector('#rotateHint')).display };
  });
  await page.evaluate(() => window.__TA.finish('blue'));
  await page.waitForTimeout(2300);
  await page.screenshot({ path: path.join(out, 'm05-result.png') });
  results.resultMetrics = await page.evaluate(() => {
    const b = document.querySelector('.result-card').getBoundingClientRect();
    return { vw: innerWidth, vh: innerHeight, card: { x: Math.round(b.x), y: Math.round(b.y), w: Math.round(b.width), h: Math.round(b.height), bottom: Math.round(b.bottom) }, scrollH: document.querySelector('.result-card').scrollHeight };
  });
  await ctx.close();

  // ---- portrait touch: rotate hint ----
  const ctx2 = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const page2 = await ctx2.newPage();
  page2.on('pageerror', e => { if (/Framebuffer status/.test(e.message)) return; errors.push('portrait: ' + e.message); });
  await page2.goto(url);
  await page2.waitForTimeout(1000);
  await page2.screenshot({ path: path.join(out, 'p01-home.png') });
  await page2.tap('#btnStart');
  await page2.waitForTimeout(500);
  await page2.screenshot({ path: path.join(out, 'p02-select.png') });
  await page2.tap('#btnGo');
  await page2.waitForTimeout(800);
  await page2.evaluate(() => window.__TA.skipCountdown());
  await page2.waitForTimeout(900);
  await page2.screenshot({ path: path.join(out, 'p03-rotate.png') });
  results.portrait = await page2.evaluate(() => ({
    rotate: getComputedStyle(document.querySelector('#rotateHint')).display,
    vw: innerWidth, vh: innerHeight,
    homeOverflow: document.documentElement.scrollWidth > innerWidth
  }));
  await ctx2.close();
  await browser.close();
  console.log('METRICS:', JSON.stringify(results, null, 2));
  console.log(errors.length ? 'ERRORS:\n' + errors.join('\n') : 'NO_PAGE_ERRORS');
})().catch(e => { console.error('FATAL', e); process.exit(1); });
