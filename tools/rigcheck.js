/* ============================================================
   tools/rigcheck.js — 渲染并截图 6 个 3D 角色骨架
   用法：node tools/rigcheck.js
   产物：tools/shots/rigs/{tpose,walk,attack}-all.png
                 tools/shots/rigs/{pose}-<hero>.png（每个角色特写）
         tools/shots/rigs/report.json（部件数 / 面数 / 身高）
   ============================================================ */
const path = require('path');
const fs = require('fs');
const { launch, shotsDir } = require('./harness');

const IDS = ['tiger', 'fox', 'rabbit', 'bear', 'otter', 'hedgehog'];
const POSES = ['tpose', 'walk', 'attack'];
const url = 'file://' + path.resolve(__dirname, '..', 'www', 'rigcheck.html').replace(/\\/g, '/');

(async () => {
  const out = shotsDir('rigs');
  const browser = await launch();
  const page = await browser.newPage({ viewport: { width: 1680, height: 960 }, deviceScaleFactor: 1 });
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });

  await page.goto(url);
  await page.waitForFunction(() => !!window.__RC && window.__RC.rigs.length === 6, null, { timeout: 15000 });

  const info = await page.evaluate(() => window.__RC.info);
  console.table(info);

  for (const pose of POSES) {
    /* 全员合影（走/攻用同一个相位，方便横向比较枢轴） */
    await page.evaluate(([p, t]) => window.__RC.setPose(p, t), [pose, 0.55]);
    await page.evaluate(() => window.__RC.wide());
    await page.waitForTimeout(120);
    await page.screenshot({ path: path.join(out, `${pose}-all.png`) });

    /* 每个角色特写 */
    for (const id of IDS) {
      await page.evaluate(([p, i]) => { window.__RC.focus(i); }, [pose, id]);
      await page.waitForTimeout(80);
      await page.screenshot({ path: path.join(out, `${pose}-${id}.png`) });
    }
    console.log('shot', pose);
  }

  const report = { generatedBy: 'tools/rigcheck.js', rigs: info, errors };
  fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
  const meshMax = Math.max(...info.map(r => r.meshes));
  console.log('maxMeshPerHero=' + meshMax, 'heights=' + info.map(r => r.id + ':' + r.height).join(' '));
  if (errors.length) console.log('ERRORS:\n' + errors.join('\n'));
  else console.log('NO_PAGE_ERRORS');

  await browser.close();
})().catch(e => { console.error('FATAL', e); process.exit(1); });
