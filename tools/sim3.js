const { launch, url } = require('./harness');
(async () => {
  const browser = await launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 760 } });
  page.on('pageerror', e => console.log('ERR', e.message));
  await page.goto(url);
  await page.waitForTimeout(700);
  for (let i = 0; i < 3; i++) {
    const t0 = Date.now();
    const r = await page.evaluate((n) => window.__TA.simulate(900, { hero: ['tiger','fox','rabbit'][n % 3], difficulty: 'easy' }), i);
    console.log('SIM' + i, JSON.stringify(r), 'ms=' + (Date.now() - t0));
  }
  const norm = await page.evaluate(() => window.__TA.simulate(900, { hero: 'tiger', difficulty: 'normal' }));
  console.log('SIM-NORMAL', JSON.stringify(norm));
  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
