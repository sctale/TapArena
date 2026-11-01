const fs = require('fs');
const path = require('path');
const { launch, url } = require('./harness');
(async () => {
  const browser = await launch();
  const page = await browser.newPage({ viewport: { width: 1000, height: 700 } });
  page.on('pageerror', e => console.log('ERR', e.message));
  await page.goto(url);
  await page.waitForTimeout(800);
  const data = await page.evaluate(() => {
    const c = document.createElement('canvas');
    c.width = 500; c.height = 500;
    const g = c.getContext('2d');
    g.fillStyle = '#8fd5ac'; g.fillRect(0,0,500,500);
    drawTree(g, 250, 380, 1.2, 0.7);
    return c.toDataURL('image/png');
  });
  fs.writeFileSync(path.join(__dirname, 'shots', 'tree-test.png'), Buffer.from(data.split(',')[1], 'base64'));
  await browser.close();
  console.log('written');
})();
