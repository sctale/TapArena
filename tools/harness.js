const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');

async function launch() {
  const args = process.platform === 'linux' ? ['--no-sandbox'] : [];
  try {
    return await chromium.launch({ headless: true, args });
  } catch (e) {
    return chromium.launch({ channel: 'msedge', headless: true, args });
  }
}
function shotsDir(sub) {
  const dir = path.join(__dirname, 'shots', sub || '');
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}
const url = 'file://' + path.resolve(__dirname, '..', 'www', 'index.html').replace(/\\/g, '/');
module.exports = { launch, shotsDir, url };
