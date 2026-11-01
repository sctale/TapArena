'use strict';
/* ============================================================
   萌兽峡谷 · 画面绘制（全部程序化，离线可用）
   ============================================================ */

/* ---------------- 基础绘制工具 ---------------- */
function ellipse(g, x, y, rx, ry, rot = 0) {
  g.beginPath();
  g.ellipse(x, y, rx, ry, rot, 0, TAU);
}
function roundRect(g, x, y, w, h, r) {
  r = Math.min(r, Math.abs(w) / 2, Math.abs(h) / 2);
  g.beginPath();
  g.moveTo(x + r, y);
  g.lineTo(x + w - r, y);
  g.quadraticCurveTo(x + w, y, x + w, y + r);
  g.lineTo(x + w, y + h - r);
  g.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  g.lineTo(x + r, y + h);
  g.quadraticCurveTo(x, y + h, x, y + h - r);
  g.lineTo(x, y + r);
  g.quadraticCurveTo(x, y, x + r, y);
  g.closePath();
}
function starPath(g, cx, cy, spikes, outer, inner, rot = -Math.PI / 2) {
  g.beginPath();
  for (let i = 0; i < spikes * 2; i++) {
    const r = i % 2 === 0 ? outer : inner;
    const a = rot + (i * Math.PI) / spikes;
    const x = cx + Math.cos(a) * r;
    const y = cy + Math.sin(a) * r;
    if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
  }
  g.closePath();
}
function drawStar(g, cx, cy, spikes, outer, inner, rot = -Math.PI / 2, fill = '#fff6d8') {
  starPath(g, cx, cy, spikes, outer, inner, rot);
  g.fillStyle = fill;
  g.fill();
}
function fillBlobs(g, color, blobs) {
  g.fillStyle = color;
  for (const b of blobs) {
    g.beginPath();
    g.ellipse(b[0], b[1], b[2], b[3], b[4] || 0, 0, TAU);
    g.fill();
  }
}
function lanePath(g) {
  g.beginPath();
  g.moveTo(LANE[0].x, LANE[0].y);
  for (let i = 1; i < LANE.length - 1; i++) {
    const xc = (LANE[i].x + LANE[i + 1].x) / 2;
    const yc = (LANE[i].y + LANE[i + 1].y) / 2;
    g.quadraticCurveTo(LANE[i].x, LANE[i].y, xc, yc);
  }
  const last = LANE[LANE.length - 1];
  g.lineTo(last.x, last.y);
}
function pointInView(x, y, pad = 200) {
  const v = RenderView;
  if (!v) return true;
  const hw = v.w / 2 + pad, hh = v.h / 2 + pad;
  return Math.abs(x - v.x) < hw && Math.abs(y - v.y) < hh;
}

/* 到主路的距离（预采样） */
const LANE_SAMPLES = (() => {
  const pts = [];
  for (let i = 0; i < LANE.length - 1; i++) {
    const a = LANE[i], b = LANE[i + 1];
    const d = Math.hypot(b.x - a.x, b.y - a.y);
    const n = Math.max(1, Math.round(d / 40));
    for (let j = 0; j < n; j++) {
      pts.push({ x: a.x + (b.x - a.x) * (j / n), y: a.y + (b.y - a.y) * (j / n) });
    }
  }
  pts.push(LANE[LANE.length - 1]);
  return pts;
})();

/* 粗略的河面范围，用来避免树木/灌木长在水里 */
function riverHalfWidth(y) {
  if (y < 380) return 150;
  if (y < 900) return 150 + (y - 380) / 520 * 85;
  if (y < 1350) return 235 - (y - 900) / 450 * 60;
  return 175;
}
function distToRiver(x, y) { return Math.abs(x - 1500) - riverHalfWidth(y); }
function inRiver(x, y, pad = 0) { return distToRiver(x, y) < pad; }

function distToLane(x, y) {
  let m = 1e9;
  for (const p of LANE_SAMPLES) {
    const d = (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y);
    if (d < m) m = d;
  }
  return Math.sqrt(m);
}

/* ============================================================
   地图背景（只画一次）
   ============================================================ */
function buildBackground() {
  const c = document.createElement('canvas');
  c.width = WORLD.w; c.height = WORLD.h;
  const g = c.getContext('2d');
  const rnd = mulberry32(20261031);
  const R = (a, b) => a + rnd() * (b - a);

  /* --- 草地底色 --- */
  const base = g.createLinearGradient(0, 0, WORLD.w, WORLD.h);
  base.addColorStop(0, '#a9e3c0');
  base.addColorStop(0.45, '#8fd5ac');
  base.addColorStop(1, '#74c49a');
  g.fillStyle = base;
  g.fillRect(0, 0, WORLD.w, WORLD.h);

  /* 大块柔光草地 */
  for (let i = 0; i < 26; i++) {
    const x = R(0, WORLD.w), y = R(0, WORLD.h), r = R(180, 520);
    const rg = g.createRadialGradient(x, y, 0, x, y, r);
    const light = rnd() > 0.45;
    rg.addColorStop(0, light ? 'rgba(213,248,222,.5)' : 'rgba(92,182,137,.32)');
    rg.addColorStop(1, 'rgba(160,220,180,0)');
    g.fillStyle = rg;
    g.fillRect(x - r, y - r, r * 2, r * 2);
  }

  /* 边缘树影暗角 */
  const edge = g.createRadialGradient(WORLD.w / 2, WORLD.h / 2, 700, WORLD.w / 2, WORLD.h / 2, 1750);
  edge.addColorStop(0, 'rgba(30,90,65,0)');
  edge.addColorStop(1, 'rgba(25,84,62,.26)');
  g.fillStyle = edge;
  g.fillRect(0, 0, WORLD.w, WORLD.h);

  /* --- 小河 --- */
  drawRiver(g, rnd);

  /* --- 小池塘 --- */
  drawPond(g, 500, 360, 128);

  /* --- 主路 --- */
  g.lineCap = 'round'; g.lineJoin = 'round';
  lanePath(g);
  g.strokeStyle = 'rgba(74,120,86,.16)';
  g.lineWidth = 300;
  g.stroke();
  lanePath(g);
  g.strokeStyle = '#e3c995';
  g.lineWidth = 278;
  g.stroke();
  lanePath(g);
  g.strokeStyle = '#f8e8c2';
  g.lineWidth = 248;
  g.stroke();
  lanePath(g);
  g.strokeStyle = 'rgba(255,250,230,.75)';
  g.lineWidth = 214;
  g.stroke();

  /* 路面颗粒与边缘石子 */
  for (let i = 0; i < 260; i++) {
    const p = LANE_SAMPLES[Math.floor(rnd() * LANE_SAMPLES.length)];
    const side = rnd() > 0.5 ? 1 : -1;
    const off = R(104, 138) * side;
    const nx = p.x + R(-14, 14), ny = p.y + off;
    g.fillStyle = rnd() > 0.5 ? 'rgba(210,176,120,.45)' : 'rgba(255,248,222,.5)';
    ellipse(g, nx, ny, R(1.5, 4), R(1.2, 2.6));
    g.fill();
  }
  for (let i = 0; i < 70; i++) {
    const p = LANE_SAMPLES[Math.floor(rnd() * LANE_SAMPLES.length)];
    const off = (rnd() > 0.5 ? 1 : -1) * R(118, 150);
    g.fillStyle = rnd() > 0.5 ? '#cfddb2' : '#bcd7ad';
    ellipse(g, p.x + R(-10, 10), p.y + off, R(4, 9), R(3, 5), R(0, 3));
    g.fill();
  }

  /* --- 营地广场 --- */
  drawPlaza(g, BASE_POS.blue.x, BASE_POS.blue.y, 'blue', rnd);
  drawPlaza(g, BASE_POS.red.x, BASE_POS.red.y, 'red', rnd);

  /* --- 木桥 --- */
  drawBridge(g);

  /* --- 蜂蜜小草地 --- */
  HONEY_SPOTS.forEach((p, i) => drawHoneyNook(g, p.x, p.y, i));

  /* --- 装饰：灌木 --- */
  BUSHES.forEach((b, i) => { if (!inRiver(b.x, b.y, 18)) drawBush(g, b.x, b.y, b.r / 60, i); });

  /* --- 树木：避开主路与营地 --- */
  const trees = [];
  for (let tries = 0; tries < 500 && trees.length < 62; tries++) {
    let x, y;
    if (trees.length % 5 < 3) {
      x = R(60, WORLD.w - 60);
      y = rnd() > 0.5 ? R(60, 470) : R(1170, WORLD.h - 60);
    } else {
      x = R(60, WORLD.w - 60);
      y = R(60, WORLD.h - 60);
    }
    if (distToLane(x, y) < 300) continue;
    if (inRiver(x, y, 55)) continue;
    if (dist(x, y, BASE_POS.blue.x, BASE_POS.blue.y) < 300) continue;
    if (dist(x, y, BASE_POS.red.x, BASE_POS.red.y) < 300) continue;
    if (HONEY_SPOTS.some(p => dist(x, y, p.x, p.y) < 150)) continue;
    if (trees.some(t => dist(t.x, t.y, x, y) < 130)) continue;
    trees.push({ x, y, s: R(0.8, 1.4), v: rnd() });
  }
  trees.sort((a, b) => a.y - b.y).forEach(t => drawTree(g, t.x, t.y, t.s, t.v));

  /* 特点灌木与花丛，让空草地更热闹 */
  [[1090, 560, 1.5, 1], [1265, 705, 1.15, 2], [1710, 1270, 1.35, 1], [1970, 700, 1.3, 2],
   [2280, 1325, 1.45, 1], [705, 540, 1.2, 2], [2470, 1265, 1.2, 1], [1555, 1335, 1.18, 2]]
    .forEach(b => { if (distToLane(b[0], b[1]) > 190 && !inRiver(b[0], b[1], 24)) drawBush(g, b[0], b[1], b[2], b[3]); });
  [[900, 610], [1490, 1370], [2075, 610], [640, 810], [2360, 690], [1320, 600]].forEach(([fx, fy]) => {
    if (distToLane(fx, fy) < 210 || inRiver(fx, fy, 30)) return;
    for (let k = 0; k < 7; k++) {
      const a = (k / 7) * TAU;
      drawFlower(g, fx + Math.cos(a) * R(18, 60), fy + Math.sin(a) * R(12, 38), R(0.7, 1.1),
        pickVal(['#fff7fa', '#ffe2ec', '#ffe89a', '#d9ecff'], rnd));
    }
  });

  /* --- 中型植被与小花 --- */
  for (let i = 0; i < 210; i++) {
    const x = R(40, WORLD.w - 40), y = R(40, WORLD.h - 40);
    if (distToLane(x, y) < 180 || inRiver(x, y, 10)) continue;
    const roll = rnd();
    if (roll < 0.4) drawFlower(g, x, y, R(0.7, 1.2), pickVal(['#fff7fa', '#ffe2ec', '#ffe89a', '#d9ecff'], rnd));
    else if (roll < 0.7) drawGrassTuft(g, x, y, R(0.7, 1.3));
    else if (roll < 0.86) drawMushroom(g, x, y, R(0.6, 1.1));
    else drawPebbles(g, x, y, R(0.7, 1.1));
  }

  /* 主路沿线的小蘑菇灯 */
  [0.08, 0.2, 0.34, 0.5, 0.66, 0.8, 0.92].forEach((t, i) => {
    const idx = Math.floor(t * (LANE_SAMPLES.length - 1));
    const p = LANE_SAMPLES[idx];
    const off = (i % 2 === 0 ? -1 : 1) * 158;
    const lx = p.x + (i % 2 ? 8 : -8), ly = p.y + off;
    if (!inRiver(lx, ly, 6)) drawLampMushroom(g, lx, ly);
  });

  /* 底部细草纹理 */
  for (let i = 0; i < 500; i++) {
    const x = R(0, WORLD.w), y = R(0, WORLD.h);
    if (distToLane(x, y) < 160 || inRiver(x, y, 6)) continue;
    g.strokeStyle = `rgba(60,140,100,${R(0.06, 0.16).toFixed(2)})`;
    g.lineWidth = 1.4;
    g.beginPath();
    g.moveTo(x, y);
    g.quadraticCurveTo(x + R(-3, 3), y - 5, x + R(-5, 5), y - R(7, 12));
    g.stroke();
  }

  /* 林间光斑与树荫：让大块草地有明暗层次 */
  for (let i = 0; i < 30; i++) {
    const x = R(0, WORLD.w), y = R(0, WORLD.h);
    if (inRiver(x, y, 24)) continue;
    const r = R(80, 260);
    const warm = rnd() > 0.32;
    const rg = g.createRadialGradient(x, y, r * 0.08, x, y, r);
    if (warm) {
      rg.addColorStop(0, `rgba(255,247,196,${R(0.06, 0.13).toFixed(2)})`);
      rg.addColorStop(1, 'rgba(255,247,196,0)');
    } else {
      rg.addColorStop(0, `rgba(46,110,80,${R(0.05, 0.1).toFixed(2)})`);
      rg.addColorStop(1, 'rgba(46,110,80,0)');
    }
    g.fillStyle = rg;
    g.fillRect(x - r, y - r, r * 2, r * 2);
  }

  /* 路边花带：让主路两沿更精致 */
  for (let i = 0; i < 46; i++) {
    const p = LANE_SAMPLES[Math.floor(rnd() * LANE_SAMPLES.length)];
    const side = rnd() > 0.5 ? 1 : -1;
    const off = side * R(146, 235);
    const x = p.x + R(-18, 18), y = p.y + off;
    if (inRiver(x, y, 20)) continue;
    if (rnd() < 0.62) {
      drawFlower(g, x, y, R(0.75, 1.15), pickVal(['#fff7fa', '#ffe2ec', '#ffe89a', '#d9ecff'], rnd));
    } else {
      drawGrassTuft(g, x, y, R(0.9, 1.5));
    }
  }

  return c;
}

function pickVal(arr, rnd) { return arr[Math.floor(rnd() * arr.length)]; }

function drawRiver(g, rnd) {
  const R = (a, b) => a + rnd() * (b - a);
  const cx = 1500;
  const topW = 150, midW = 235, botW = 175;
  g.save();
  g.beginPath();
  g.moveTo(cx - topW, -20);
  g.bezierCurveTo(cx - topW - 60, 380, cx - midW - 30, 700, cx - midW, 900);
  g.bezierCurveTo(cx - midW, 1120, cx - botW - 40, 1350, cx - botW, WORLD.h + 20);
  g.lineTo(cx + botW, WORLD.h + 20);
  g.bezierCurveTo(cx + botW + 40, 1350, cx + midW, 1120, cx + midW, 900);
  g.bezierCurveTo(cx + midW + 30, 700, cx + topW + 60, 380, cx + topW, -20);
  g.closePath();
  const rg = g.createLinearGradient(cx - 250, 0, cx + 250, 0);
  rg.addColorStop(0, '#8ed3e3');
  rg.addColorStop(0.3, '#b8ecf4');
  rg.addColorStop(0.55, '#9fe2ee');
  rg.addColorStop(1, '#7fc8dc');
  g.fillStyle = rg;
  g.fill();
  g.strokeStyle = 'rgba(255,255,255,.4)';
  g.lineWidth = 5;
  g.stroke();

  /* 河岸浅色 */
  g.beginPath();
  g.moveTo(cx - topW - 14, -20);
  g.bezierCurveTo(cx - topW - 74, 380, cx - midW - 44, 700, cx - midW - 14, 900);
  g.bezierCurveTo(cx - midW - 14, 1120, cx - botW - 54, 1350, cx - botW - 14, WORLD.h + 20);
  g.strokeStyle = 'rgba(238,248,214,.7)';
  g.lineWidth = 20;
  g.stroke();

  /* 水纹 */
  for (let i = 0; i < 46; i++) {
    const y = rnd() * WORLD.h;
    const x = cx + (rnd() - 0.5) * 220;
    g.strokeStyle = `rgba(255,255,255,${(0.12 + rnd() * 0.25).toFixed(2)})`;
    g.lineWidth = R(1.5, 3);
    g.beginPath();
    g.arc(x, y, R(8, 26), Math.PI * 1.1, Math.PI * 1.55);
    g.stroke();
  }
  /* 荷叶 */
  for (let i = 0; i < 9; i++) {
    const y = 200 + rnd() * 1200;
    const x = cx + (rnd() - 0.5) * 190;
    g.fillStyle = 'rgba(110,190,140,.9)';
    ellipse(g, x, y, R(9, 16), R(5, 9), rnd());
    g.fill();
    g.fillStyle = 'rgba(255,255,255,.35)';
    ellipse(g, x - 3, y - 2, 3, 1.6);
    g.fill();
  }
  /* 河岸石头 */
  for (let i = 0; i < 20; i++) {
    const y = rnd() * WORLD.h;
    const side = rnd() > 0.5 ? 1 : -1;
    const x = cx + side * (midW * 0.7 + R(30, 100));
    g.fillStyle = 'rgba(180,205,175,.85)';
    ellipse(g, x, y, R(6, 14), R(4, 8), rnd());
    g.fill();
  }
  /* 芦苇 */
  for (let i = 0; i < 26; i++) {
    const y = rnd() * WORLD.h;
    const side = rnd() > 0.5 ? 1 : -1;
    const x = cx + side * (midW * 0.75 + R(16, 70));
    g.strokeStyle = '#5f9f72';
    g.lineWidth = 2.4;
    g.beginPath();
    g.moveTo(x, y);
    g.quadraticCurveTo(x + R(-6, 6), y - 20, x + R(-10, 10), y - R(28, 46));
    g.stroke();
    g.fillStyle = '#e4cf8f';
    ellipse(g, x, y - 32, 2.6, 7);
    g.fill();
  }
  g.restore();
}

function drawPond(g, x, y, r) {
  const rg = g.createRadialGradient(x, y, r * 0.2, x, y, r);
  rg.addColorStop(0, '#c8f2f0');
  rg.addColorStop(0.7, '#9adfe2');
  rg.addColorStop(1, '#7cc9cd');
  g.fillStyle = '#dff0cf';
  ellipse(g, x, y, r + 14, r * 0.8 + 12);
  g.fill();
  g.fillStyle = rg;
  ellipse(g, x, y, r, r * 0.78);
  g.fill();
  g.strokeStyle = 'rgba(255,255,255,.5)';
  g.lineWidth = 3;
  for (let i = 0; i < 4; i++) {
    ellipse(g, x - r * 0.4 + i * 18, y - 14 + i * 12, 26 - i * 3, 7 - i);
    g.stroke();
  }
  for (let i = 0; i < 4; i++) {
    g.fillStyle = 'rgba(104,186,130,.95)';
    ellipse(g, x - 40 + i * 28, y + 10 + Math.sin(i) * 16, 12, 6, 0.2);
    g.fill();
  }
  g.fillStyle = 'rgba(255,231,245,.9)';
  for (let i = 0; i < 3; i++) {
    ellipse(g, x + 30 + i * 12, y - 30 + i * 8, 4, 2.2);
    g.fill();
  }
}

function drawPlaza(g, x, y, team, rnd) {
  const col = team === 'blue' ? ['#ffeccb', '#f6dfb4'] : ['#ffe8cd', '#f6d8b7'];
  const glow = team === 'blue' ? 'rgba(94,196,188,.28)' : 'rgba(255,150,124,.28)';
  const rg = g.createRadialGradient(x, y, 20, x, y, 240);
  rg.addColorStop(0, col[0]);
  rg.addColorStop(0.65, col[1]);
  rg.addColorStop(1, 'rgba(250,232,196,0)');
  g.fillStyle = rg;
  ellipse(g, x, y, 250, 210);
  g.fill();

  g.strokeStyle = glow;
  g.lineWidth = 12;
  ellipse(g, x, y, 190, 158);
  g.stroke();
  g.strokeStyle = 'rgba(255,255,255,.5)';
  g.lineWidth = 3;
  ellipse(g, x, y, 200, 167);
  g.stroke();

  /* 花瓣环 */
  const petal = team === 'blue' ? ['#8fe0d0', '#ffead1', '#bdf0dc'] : ['#ffb09a', '#ffe6c7', '#ffc9b5'];
  for (let i = 0; i < 22; i++) {
    const a = (i / 22) * TAU + 0.2;
    drawFlower(g, x + Math.cos(a) * 214, y + Math.sin(a) * 176, 0.8 + rnd() * 0.4, petal[i % petal.length]);
  }
  /* 小旗子 */
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * TAU + Math.PI / 4;
    const px = x + Math.cos(a) * 236, py = y + Math.sin(a) * 190;
    g.strokeStyle = '#b98d5e';
    g.lineWidth = 3.4;
    g.beginPath();
    g.moveTo(px, py);
    g.lineTo(px, py - 46);
    g.stroke();
    g.fillStyle = team === 'blue' ? '#39b8ae' : '#ff8f73';
    g.beginPath();
    g.moveTo(px, py - 46);
    g.quadraticCurveTo(px + 20, py - 40, px + 26, py - 30);
    g.quadraticCurveTo(px + 12, py - 26, px, py - 28);
    g.closePath();
    g.fill();
  }
}

function drawBridge(g) {
  const x = 1500, y = 878;
  g.save();
  g.translate(x, y);
  /* 桥影 */
  g.fillStyle = 'rgba(40,80,60,.2)';
  roundRect(g, -242, -118, 484, 248, 30);
  g.fill();
  /* 桥面（横跨小河） */
  const grd = g.createLinearGradient(0, -120, 0, 120);
  grd.addColorStop(0, '#e9c995');
  grd.addColorStop(0.5, '#f3d9a9');
  grd.addColorStop(1, '#d7b078');
  g.fillStyle = grd;
  roundRect(g, -238, -112, 476, 224, 26);
  g.fill();
  g.strokeStyle = 'rgba(150,105,58,.55)';
  g.lineWidth = 3;
  g.stroke();
  /* 木板缝（垂直于行走方向） */
  g.strokeStyle = 'rgba(158,112,62,.3)';
  g.lineWidth = 2.5;
  for (let i = -8; i <= 8; i++) {
    g.beginPath();
    g.moveTo(i * 27, -104);
    g.lineTo(i * 27, 104);
    g.stroke();
  }
  /* 板头高光 */
  g.strokeStyle = 'rgba(255,255,255,.2)';
  g.lineWidth = 1.4;
  for (let i = -8; i <= 8; i++) {
    g.beginPath();
    g.moveTo(i * 27 + 2, -100);
    g.lineTo(i * 27 + 2, 100);
    g.stroke();
  }
  /* 栏杆 */
  g.fillStyle = '#c8955c';
  roundRect(g, -246, -126, 492, 16, 8);
  g.fill();
  roundRect(g, -246, 110, 492, 16, 8);
  g.fill();
  g.fillStyle = '#e8c48e';
  roundRect(g, -246, -126, 492, 6, 3);
  g.fill();
  roundRect(g, -246, 110, 492, 6, 3);
  g.fill();
  g.fillStyle = '#b9884f';
  for (let i = -9; i <= 9; i++) {
    roundRect(g, i * 25 - 3, -130, 6, 22, 3);
    g.fill();
    roundRect(g, i * 25 - 3, 108, 6, 22, 3);
    g.fill();
  }
  /* 桥头灯柱 */
  [-238, 238].forEach(px => {
    g.strokeStyle = '#9c7749';
    g.lineWidth = 4;
    g.beginPath();
    g.moveTo(px, -110);
    g.lineTo(px, -160);
    g.stroke();
    const lg = g.createRadialGradient(px, -166, 2, px, -166, 28);
    lg.addColorStop(0, 'rgba(255,230,160,.7)');
    lg.addColorStop(1, 'rgba(255,230,160,0)');
    g.fillStyle = lg;
    ellipse(g, px, -166, 28, 28);
    g.fill();
    g.fillStyle = '#ffe3a0';
    ellipse(g, px, -162, 7, 8);
    g.fill();
  });
  /* 桥边小花 */
  [-200, -150, 160, 210].forEach(px => {
    drawFlower(g, px, -104, 0.8, px < 0 ? '#ffd9e3' : '#fff3b8');
  });
  g.restore();
}
function drawHoneyNook(g, x, y, i) {
  g.fillStyle = 'rgba(255,244,204,.45)';
  ellipse(g, x, y, 105, 80);
  g.fill();
  for (let k = 0; k < 9; k++) {
    const a = (k / 9) * TAU;
    drawFlower(g, x + Math.cos(a) * (70 + (k % 3) * 12), y + Math.sin(a) * (52 + (k % 2) * 10), 0.8, k % 2 ? '#ffe6a8' : '#ffd9e3');
  }
  /* 小树桩 */
  g.fillStyle = '#c9a678';
  roundRect(g, x - 26, y - 44, 52, 30, 10);
  g.fill();
  g.fillStyle = '#e7cca2';
  ellipse(g, x, y - 44, 26, 10);
  g.fill();
  g.strokeStyle = '#b58e5c';
  g.lineWidth = 2;
  ellipse(g, x, y - 44, 16, 5.5);
  g.stroke();
}

/* ---------------- 动态环境光与水 --------------- */
const RIVER_SPARKS = (() => {
  const rnd = mulberry32(9182);
  const arr = [];
  for (let i = 0; i < 34; i++) {
    const y = rnd() * WORLD.h;
    const w = Math.max(20, riverHalfWidth(y) - 28);
    arr.push({
      x: 1500 + (rnd() * 2 - 1) * w,
      y,
      ph: rnd() * TAU,
      sp: 0.7 + rnd() * 1.1,
      len: 1.6 + rnd() * 2.6
    });
  }
  return arr;
})();

let cloudShadowCanvas = null, cloudLightCanvas = null;
function ensureCloudCanvases() {
  if (cloudShadowCanvas) return;
  const bake = (inner, mid) => {
    const c = document.createElement('canvas');
    c.width = c.height = 128;
    const cg = c.getContext('2d');
    const grad = cg.createRadialGradient(64, 64, 6, 64, 64, 62);
    grad.addColorStop(0, inner);
    grad.addColorStop(0.68, mid);
    grad.addColorStop(1, 'rgba(0,0,0,0)');
    cg.fillStyle = grad;
    cg.fillRect(0, 0, 128, 128);
    return c;
  };
  cloudShadowCanvas = bake('rgba(34,92,68,.115)', 'rgba(34,92,68,.055)');
  cloudLightCanvas = bake('rgba(255,250,214,.07)', 'rgba(255,248,205,.03)');
}

function drawCloudShadows(g, time) {
  const clouds = [
    { x: 620, y: 400, rx: 640, ry: 300, ph: 0.0, sp: 0.014, light: false },
    { x: 1750, y: 780, rx: 720, ry: 330, ph: 2.2, sp: 0.011, light: true },
    { x: 2380, y: 350, rx: 560, ry: 260, ph: 4.1, sp: 0.016, light: false },
    { x: 1150, y: 1280, rx: 600, ry: 280, ph: 1.1, sp: 0.012, light: false }
  ];
  ensureCloudCanvases();
  g.save();
  clouds.forEach(c => {
    const x = c.x + Math.sin(time * c.sp + c.ph) * 280;
    const y = c.y + Math.cos(time * c.sp * 0.8 + c.ph) * 130;
    g.drawImage(c.light ? cloudLightCanvas : cloudShadowCanvas,
      x - c.rx, y - c.ry, c.rx * 2, c.ry * 2);
  });
  g.restore();
}

const KOI_FISH = [
  { y: 470, xo: -40, ph: 0.4, s: 1.0, color: '#ff9f6e' },
  { y: 1040, xo: 58, ph: 2.3, s: 1.25, color: '#ffc177' },
  { y: 1290, xo: -10, ph: 4.0, s: 0.85, color: '#ff8e6a' }
];

function drawRiverLife(g, time) {
  /* 水面闪光 */
  g.save();
  g.globalCompositeOperation = 'lighter';
  for (let i = 0; i < RIVER_SPARKS.length; i++) {
    const s = RIVER_SPARKS[i];
    if (!pointInView(s.x, s.y, 60)) continue;
    const a = Math.max(0, Math.sin(time * s.sp + s.ph));
    if (a < 0.12) continue;
    g.globalAlpha = a * 0.55;
    g.strokeStyle = '#ffffff';
    g.lineWidth = 1.5;
    g.lineCap = 'round';
    g.beginPath();
    g.moveTo(s.x - s.len * 2.2, s.y);
    g.quadraticCurveTo(s.x, s.y - 1.5, s.x + s.len * 2.2, s.y);
    g.stroke();
    if (a > 0.7) drawStar(g, s.x + s.len * 2.6, s.y - 1, 4, 2.6, 1, 0, 'rgba(255,255,255,.8)');
  }
  g.restore();

  /* 小锦鲤 */
  KOI_FISH.forEach((k, i) => {
    const x = 1500 + k.xo + Math.sin(time * 0.38 + k.ph) * 46;
    const y = k.y + Math.cos(time * 0.31 + k.ph) * 16;
    if (!pointInView(x, y, 60)) return;
    const dir = Math.cos(time * 0.38 + k.ph) >= 0 ? 1 : -1;
    const tail = Math.sin(time * 3.2 + k.ph) * 0.25;
    g.save();
    g.translate(x, y);
    g.scale(k.s * (dir > 0 ? 1 : -1), k.s);
    g.fillStyle = k.color;
    g.beginPath();
    g.moveTo(-12, 0);
    g.quadraticCurveTo(-20, -6 + tail * 8, -23, -1);
    g.quadraticCurveTo(-20, 2 + tail * 6, -12, 2);
    g.closePath();
    g.fill();
    g.beginPath();
    g.ellipse(2, 0, 11, 6, 0, 0, TAU);
    g.fill();
    g.fillStyle = 'rgba(255,245,220,.75)';
    g.beginPath();
    g.ellipse(-1, -1, 5.5, 3, 0.2, 0, TAU);
    g.fill();
    g.fillStyle = '#573e35';
    ellipse(g, 9, -1.4, 1.7, 1.7);
    g.fill();
    g.strokeStyle = 'rgba(255,255,255,.35)';
    g.lineWidth = 1.4;
    ellipse(g, 0, 1.5, 16, 7);
    g.stroke();
    g.restore();
  });
}

/* 屏幕氛围整屏缓存：暖阳/柔光/暗角与低血红晕只在尺寸变化时重建，
   避免每帧创建 3~4 个全屏径向渐变（Android WebView 上很吃填充率）。 */
let moodCanvas = null, moodW = 0, moodH = 0, dangerCanvas = null;

function buildMoodCache(cw, ch) {
  const s = Math.min(1.5, typeof PIXEL_RATIO === 'number' ? PIXEL_RATIO : 1) || 1;
  const bake = () => {
    const c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(cw * s));
    c.height = Math.max(1, Math.round(ch * s));
    const m = c.getContext('2d');
    m.scale(s, s);
    return { c, m };
  };

  const mood = bake();
  const m = mood.m;
  const sun = m.createRadialGradient(cw * 0.82, -ch * 0.12, 20, cw * 0.82, -ch * 0.12, Math.max(cw, ch) * 0.68);
  sun.addColorStop(0, 'rgba(255,245,192,.20)');
  sun.addColorStop(0.45, 'rgba(255,238,176,.06)');
  sun.addColorStop(1, 'rgba(255,238,176,0)');
  m.fillStyle = sun;
  m.fillRect(0, 0, cw, ch);
  /* 右上角柔光晕染 */
  m.save();
  m.globalCompositeOperation = 'lighter';
  m.globalAlpha = 0.6;
  const wash = m.createRadialGradient(cw * 0.78, ch * 0.04, 20, cw * 0.78, ch * 0.04, cw * 0.62);
  wash.addColorStop(0, 'rgba(255,247,205,.12)');
  wash.addColorStop(0.5, 'rgba(255,244,195,.045)');
  wash.addColorStop(1, 'rgba(255,244,195,0)');
  m.fillStyle = wash;
  m.fillRect(0, 0, cw, ch);
  m.restore();
  /* 柔和暗角 */
  const vig = m.createRadialGradient(cw / 2, ch * 0.48, Math.min(cw, ch) * 0.3, cw / 2, ch * 0.5, Math.hypot(cw, ch) * 0.62);
  vig.addColorStop(0, 'rgba(12,52,40,0)');
  vig.addColorStop(0.72, 'rgba(12,52,40,.045)');
  vig.addColorStop(1, 'rgba(10,45,34,.28)');
  m.fillStyle = vig;
  m.fillRect(0, 0, cw, ch);
  moodCanvas = mood.c;

  /* 低血红色晕：烘焙最大强度，画的时候用 globalAlpha 调深浅 */
  const danger = bake();
  const d = danger.m;
  const low = d.createRadialGradient(cw / 2, ch / 2, Math.min(cw, ch) * 0.24, cw / 2, ch / 2, Math.hypot(cw, ch) * 0.62);
  low.addColorStop(0, 'rgba(255,60,60,0)');
  low.addColorStop(0.68, 'rgba(255,72,64,.095)');
  low.addColorStop(1, 'rgba(206,36,40,.33)');
  d.fillStyle = low;
  d.fillRect(0, 0, cw, ch);
  dangerCanvas = danger.c;

  moodW = cw;
  moodH = ch;
}

function drawScreenMood(ctx, cw, ch, worldTime, timeSec) {
  if (!moodCanvas || moodW !== cw || moodH !== ch) buildMoodCache(cw, ch);
  ctx.drawImage(moodCanvas, 0, 0, cw, ch);

  /* 低血量红晕 */
  if (player && player.alive && player.hp / player.maxHp < 0.38) {
    const danger = 1 - player.hp / player.maxHp / 0.38;
    const pulse = 0.55 + Math.sin(worldTime * 5.4) * 0.45;
    ctx.save();
    ctx.globalAlpha = clamp((0.3 + danger * 0.7) * pulse, 0, 1);
    ctx.drawImage(dangerCanvas, 0, 0, cw, ch);
    ctx.restore();
  }
}

function drawTree(g, x, y, s, v) {
  g.save();
  g.translate(x, y);
  g.scale(s, s);
  /* 影子 */
  g.fillStyle = 'rgba(40,90,66,.18)';
  ellipse(g, 10, 2, 54, 16);
  g.fill();
  /* 树干 */
  g.fillStyle = '#aa7b57';
  roundRect(g, -9, -70, 18, 72, 8);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.18)';
  roundRect(g, -7, -68, 5, 60, 3);
  g.fill();
  /* 树冠 */
  const deep = '#3f9069';
  const mid = '#5cae7d';
  const light = '#7fcf95';
  fillBlobs(g, deep, [[0, -94, 54, 43], [-38, -72, 33, 28], [40, -76, 35, 30]]);
  fillBlobs(g, mid, [[-6, -103, 45, 34], [-34, -84, 27, 22], [34, -88, 28, 23]]);
  fillBlobs(g, light, [[-14, -111, 28, 20], [18, -99, 21, 15]]);
  if (v > 0.6) {
    g.fillStyle = 'rgba(255,240,180,.85)';
    for (let i = 0; i < 3; i++) {
      ellipse(g, -20 + i * 22, -108 + (i % 2) * 18, 3, 3);
      g.fill();
    }
  }
  g.restore();
}

function drawBush(g, x, y, s, v) {
  g.save();
  g.translate(x, y);
  g.scale(s, s);
  g.fillStyle = 'rgba(40,90,66,.14)';
  ellipse(g, 4, 6, 54, 16);
  g.fill();
  fillBlobs(g, '#4f9a6f', [[-24, -12, 28, 22], [24, -14, 30, 23], [0, -26, 34, 28]]);
  fillBlobs(g, '#6cba87', [[-16, -26, 20, 15], [18, -30, 22, 16]]);
  g.fillStyle = 'rgba(200,245,205,.55)';
  ellipse(g, 4, -38, 16, 9);
  g.fill();
  if (v % 2 === 0) {
    g.fillStyle = '#ffdfe7';
    for (let i = 0; i < 4; i++) {
      ellipse(g, -30 + i * 18, -14 + (i % 2) * -8, 3.4, 3);
      g.fill();
    }
  }
  g.restore();
}

function drawFlower(g, x, y, s, color) {
  g.save();
  g.translate(x, y);
  g.scale(s, s);
  g.strokeStyle = '#5fa575';
  g.lineWidth = 1.6;
  g.beginPath();
  g.moveTo(0, 0);
  g.quadraticCurveTo(1, -5, 0, -9);
  g.stroke();
  g.fillStyle = color;
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * TAU - Math.PI / 2;
    ellipse(g, Math.cos(a) * 4, -9 + Math.sin(a) * 4, 3.2, 2.6, a);
    g.fill();
  }
  g.fillStyle = '#f6c85a';
  ellipse(g, 0, -9, 2.2, 2.2);
  g.fill();
  g.restore();
}

function drawGrassTuft(g, x, y, s) {
  g.save();
  g.translate(x, y);
  g.scale(s, s);
  g.strokeStyle = 'rgba(63,140,96,.6)';
  g.lineWidth = 2.2;
  g.lineCap = 'round';
  for (let i = -1; i <= 1; i++) {
    g.beginPath();
    g.moveTo(i * 4, 0);
    g.quadraticCurveTo(i * 7, -8, i * 10 + 2, -15 - Math.abs(i) * 2);
    g.stroke();
  }
  g.restore();
}

function drawMushroom(g, x, y, s) {
  g.save();
  g.translate(x, y);
  g.scale(s, s);
  g.fillStyle = 'rgba(40,90,66,.14)';
  ellipse(g, 4, 2, 18, 6);
  g.fill();
  g.fillStyle = '#f5e5c4';
  roundRect(g, -5, -18, 10, 20, 4);
  g.fill();
  g.fillStyle = '#ff9a86';
  g.beginPath();
  g.ellipse(0, -20, 17, 12, 0, Math.PI, TAU);
  g.closePath();
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.85)';
  ellipse(g, -6, -24, 3, 2.4);
  ellipse(g, 5, -27, 2.6, 2);
  g.fill();
  g.restore();
}

function drawPebbles(g, x, y, s) {
  g.save();
  g.translate(x, y);
  g.scale(s, s);
  g.fillStyle = 'rgba(159,184,156,.9)';
  ellipse(g, 0, 0, 9, 5);
  ellipse(g, 12, 3, 6, 4);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.35)';
  ellipse(g, -2, -2, 3, 1.6);
  g.fill();
  g.restore();
}

function drawLampMushroom(g, x, y) {
  g.save();
  g.translate(x, y);
  const glow = g.createRadialGradient(0, -24, 2, 0, -24, 46);
  glow.addColorStop(0, 'rgba(255,236,166,.5)');
  glow.addColorStop(1, 'rgba(255,236,166,0)');
  g.fillStyle = glow;
  ellipse(g, 0, -24, 46, 46);
  g.fill();
  g.fillStyle = '#cdeadd';
  roundRect(g, -4, -26, 8, 28, 4);
  g.fill();
  g.fillStyle = '#ffd98a';
  g.beginPath();
  g.ellipse(0, -30, 13, 10, 0, Math.PI, TAU);
  g.closePath();
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.75)';
  ellipse(g, 0, -38, 2.4, 1.8);
  g.fill();
  g.restore();
}

/* ============================================================
   英雄造型
   ============================================================ */
let softShadowCanvas = null;
function drawSoftShadow(g, x, y, rx, ry, alpha) {
  if (!softShadowCanvas) {
    softShadowCanvas = document.createElement('canvas');
    softShadowCanvas.width = softShadowCanvas.height = 128;
    const sg = softShadowCanvas.getContext('2d');
    const grad = sg.createRadialGradient(64, 64, 4, 64, 64, 62);
    grad.addColorStop(0, 'rgba(24,68,48,.58)');
    grad.addColorStop(0.55, 'rgba(24,68,48,.26)');
    grad.addColorStop(1, 'rgba(24,68,48,0)');
    sg.fillStyle = grad;
    sg.fillRect(0, 0, 128, 128);
  }
  g.save();
  g.globalAlpha = alpha;
  g.drawImage(softShadowCanvas, x - rx, y - ry, rx * 2, ry * 2);
  g.restore();
}

function drawHeroSprite(g, h, time) {
  if (!h.alive && (!h.deathT || h.deathT <= 0)) return;
  const def = HERO_DEFS[h.heroId];
  /* 姿势全部由 anim.js 的关键帧 clip 采样得到，这里只负责画 */
  const pose = buildPose(h, time);
  const dying = pose.dying > 0;
  const dyingP = pose.deathP;
  const moving = pose.moving;
  const phase = moving ? pose.phase * Math.PI * 2 : 0;
  const walkSin = pose.walkSin;
  const atk = pose.atk;
  const cast = pose.cast;
  const hurt = pose.hurt;
  const spinRaw = pose.spinRaw;
  const bob = pose.bob;
  const legSwing = pose.legSwing;
  const lift = pose.lift;
  const lean = pose.lean;
  const lunge = pose.lunge;
  const squashY = pose.squashY;
  const squashX = pose.squashX;
  const alpha = pose.alpha;
  const face = h.facing >= 0 ? 1 : -1;
  const stepBounce = moving ? Math.abs(walkSin) : 0;
  pose.walkSin = walkSin;

  g.save();
  g.translate(h.x, h.y);
  drawSoftShadow(g, -face * 2, 3, (30 + stepBounce * 2) * (1 - cast * 0.1), 11, (dying ? 0.14 : 0.3) * (1 - dyingP * 0.75));

  if (!dying) {
    /* 队伍光环 */
    const tc = teamColor(h.team);
    const pulse = 0.5 + Math.sin(time * 3 + h.seed) * 0.08;
    const footGlow = g.createRadialGradient(0, 0, 2, 0, 0, 48);
    footGlow.addColorStop(0, h.team === 'blue' ? 'rgba(110,240,232,.26)' : 'rgba(255,154,128,.26)');
    footGlow.addColorStop(1, h.team === 'blue' ? 'rgba(110,240,232,0)' : 'rgba(255,154,128,0)');
    g.fillStyle = footGlow;
    ellipse(g, 0, 0, 48, 20);
    g.fill();

    g.strokeStyle = tc;
    g.globalAlpha = h.isPlayer ? 0.9 : pulse;
    g.lineWidth = h.isPlayer ? 3 : 2.2;
    ellipse(g, 0, 1, 32, 11);
    g.stroke();
    if (h.isPlayer) {
      g.setLineDash([6, 8]);
      g.lineDashOffset = -time * 12;
      g.globalAlpha = 0.55;
      g.lineWidth = 1.8;
      ellipse(g, 0, 1, 38, 14);
      g.stroke();
      g.setLineDash([]);
      g.fillStyle = 'rgba(255,224,150,.14)';
      ellipse(g, 0, 1, 34, 13);
      g.fill();
    }
    g.globalAlpha = 1;

    /* 背后小队旗：贴在肩后的小三角旗，避免像手持武器 */
    g.save();
    g.translate(-23, -64);
    g.rotate(-0.32 + Math.sin(time * 1.6 + h.seed) * 0.05);
    g.strokeStyle = '#9c7a52';
    g.lineWidth = 2;
    g.beginPath(); g.moveTo(0, 7); g.lineTo(0, -9); g.stroke();
    g.fillStyle = tc;
    g.beginPath();
    g.moveTo(0, -9);
    g.quadraticCurveTo(6, -8.4 + Math.sin(time * 5) * 0.9, 11, -5);
    g.quadraticCurveTo(5.6, -1.8 + Math.sin(time * 5) * 0.7, 0, -1.4);
    g.closePath();
    g.fill();
    g.restore();

    /* 队伍色柔和光晕 */
    g.save();
    const aura = g.createRadialGradient(0, -42, 4, 0, -42, 58);
    aura.addColorStop(0, h.team === 'blue' ? 'rgba(96,225,225,.2)' : 'rgba(255,135,110,.22)');
    aura.addColorStop(1, h.team === 'blue' ? 'rgba(96,225,225,0)' : 'rgba(255,135,110,0)');
    g.fillStyle = aura;
    ellipse(g, 0, -42, 58, 62);
    g.fill();
    g.restore();

    if (cast > 0.04) {
      g.save();
      g.globalCompositeOperation = 'lighter';
      g.globalAlpha = cast * 0.32;
      const cc = h.team === 'blue' ? '120,245,238' : '255,190,150';
      const cg = g.createRadialGradient(0, -46, 18, 0, -46, 38 + cast * 22);
      cg.addColorStop(0, `rgba(${cc},0)`);
      cg.addColorStop(0.7, `rgba(${cc},.42)`);
      cg.addColorStop(1, `rgba(${cc},0)`);
      g.fillStyle = cg;
      ellipse(g, 0, -46, 38 + cast * 22, 42 + cast * 24);
      g.fill();
      g.restore();
    }
  }

  /* 身体：蓄力后倾 → 出招前冲，带挤压拉伸与旋转 */
  g.save();
  g.globalAlpha = alpha;
  if (dying) {
    g.translate(0, -dyingP * 26);
    g.rotate(face * dyingP * 0.55);
  }
  g.translate(lunge - hurt * (h.hitDir || 1) * 4, -lift + bob);
  g.rotate(lean * face);
  g.scale(face * squashX, squashY);

  if (spinRaw > 0) {
    const spinAngle = spinRaw * TAU * 2;
    for (let k = 2; k >= 1; k--) {
      g.save();
      g.globalAlpha = alpha * (0.08 + k * 0.045);
      g.translate(0, -46);
      g.rotate(spinAngle - k * 0.7);
      g.translate(0, 46);
      drawHeroBody(g, def, pose, h, time);
      g.restore();
    }
    g.translate(0, -46);
    g.rotate(spinAngle);
    g.translate(0, 46);
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = alpha * 0.5;
    g.strokeStyle = h.team === 'blue' ? 'rgba(160,255,240,.8)' : 'rgba(255,214,160,.8)';
    g.lineWidth = 5;
    g.beginPath();
    g.arc(0, -46, 56, -0.7, 1.4);
    g.stroke();
    g.beginPath();
    g.arc(0, -46, 42, Math.PI - 0.2, Math.PI + 1.8);
    g.stroke();
    g.restore();
  }

  /* 出招瞬间的拖影：让挥击有速度感而不是瞬移换姿势 */
  if (!dying && h.atkAnim > 0 && h.atkAnim < 0.19) {
    const gp = 1 - h.atkAnim / 0.19;
    const ghostA = Math.sin(clamp(gp * 1.15, 0, 1) * Math.PI) * 0.32;
    for (let k = 2; k >= 1; k--) {
      g.save();
      g.globalAlpha = alpha * ghostA / (k * 1.7);
      g.translate(-face * k * 7, 0);
      g.scale(1 - k * 0.012, 1 + k * 0.008);
      drawHeroBody(g, def, pose, h, time);
      g.restore();
    }
  }

  drawHeroBody(g, def, pose, h, time);
  g.restore();

  /* 受击白闪 */
  if (hurt > 0.02) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = hurt * 0.24;
    const fg = g.createRadialGradient(0, -48, 2, 0, -48, 30);
    fg.addColorStop(0, 'rgba(255,255,255,.85)');
    fg.addColorStop(0.55, 'rgba(255,245,225,.35)');
    fg.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = fg;
    ellipse(g, 0, -48, 30, 36);
    g.fill();
    g.restore();
  }

  /* 受击冲击线：明确后仰方向 */
  if (hurt > 0.04) {
    const dir = h.hitDir || 1;
    g.save();
    g.translate(0, -46);
    g.rotate(-dir * 0.35);
    g.globalAlpha = hurt * 0.85;
    g.strokeStyle = 'rgba(255,128,96,.9)';
    g.lineWidth = 3;
    g.lineCap = 'round';
    for (let i = 0; i < 3; i++) {
      const ly = (i - 1) * 11;
      g.beginPath();
      g.moveTo(dir * (30 + i * 3), ly);
      g.lineTo(dir * (44 + i * 6), ly * 1.25);
      g.stroke();
    }
    g.globalAlpha = hurt * 0.9;
    drawStar(g, dir * 24, 0, 4, 7 + hurt * 5, 2.6, time * 3, '#ffd9b0');
    g.restore();
  }

  /* 死亡灵光 */
  if (dying) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = clamp(1 - dyingP * 0.9, 0, 1) * 0.9;
    const sy = -78 - dyingP * 62;
    const sg = g.createRadialGradient(0, sy, 2, 0, sy, 26);
    sg.addColorStop(0, 'rgba(255,252,220,.9)');
    sg.addColorStop(0.5, h.team === 'blue' ? 'rgba(160,250,240,.35)' : 'rgba(255,200,170,.35)');
    sg.addColorStop(1, 'rgba(255,250,220,0)');
    g.fillStyle = sg;
    ellipse(g, 0, sy, 26, 28);
    g.fill();
    for (let i = 0; i < 3; i++) {
      const a = time * 2.2 + h.seed + i * 2.1;
      drawStar(g, Math.sin(a) * 18, sy - 10 - i * 14, 4, 4.5 - i, 1.8, a, 'rgba(255,248,205,.9)');
    }
    g.restore();
  }

  if (!dying) {
    /* 护盾泡泡 */
    if (h.shield > 0) {
      const pulse = Math.sin(time * 6) * 2;
      g.strokeStyle = 'rgba(140,235,255,.8)';
      g.fillStyle = 'rgba(150,230,255,.14)';
      g.lineWidth = 2;
      ellipse(g, 0, -46, 44 + pulse, 48 + pulse);
      g.fill();
      g.stroke();
      g.beginPath();
      g.arc(-16, -70, 9, Math.PI * 0.15, Math.PI * 0.7);
      g.strokeStyle = 'rgba(255,255,255,.7)';
      g.lineWidth = 2;
      g.stroke();
    }

    /* 眩晕星星 */
    if (h.stunT > 0) {
      for (let i = 0; i < 3; i++) {
        const a = time * 5 + (i / 3) * TAU;
        drawStar(g, Math.cos(a) * 20, -100 + Math.sin(a) * 6, 5, 4, 1.8, 0, '#ffe07a');
      }
    }

    /* 玩家标记 */
    if (h.isPlayer) {
      const by = -136 + Math.sin(time * 3.4) * 4;
      const glow = g.createRadialGradient(0, by, 2, 0, by, 24);
      glow.addColorStop(0, 'rgba(255,224,130,.5)');
      glow.addColorStop(1, 'rgba(255,224,130,0)');
      g.fillStyle = glow;
      ellipse(g, 0, by, 24, 24);
      g.fill();
      g.fillStyle = '#ffe07a';
      g.strokeStyle = 'rgba(120,80,25,.5)';
      g.lineWidth = 1.2;
      g.beginPath();
      g.moveTo(0, by - 15);
      g.lineTo(11, by);
      g.lineTo(3, by);
      g.lineTo(3, by + 6);
      g.lineTo(-3, by + 6);
      g.lineTo(-3, by);
      g.lineTo(-11, by);
      g.closePath();
      g.fill();
      g.stroke();
    }
  }
  g.restore();
}

function drawHeroBody(g, def, pose, h, time) {
  if (h.heroId === 'tiger') drawTigerBody(g, def, pose.bob, pose.legSwing, time, h, pose);
  else if (h.heroId === 'fox') drawFoxBody(g, def, pose.bob, pose.legSwing, time, h, pose);
  else if (h.heroId === 'bear') drawBearBody(g, def, pose.bob, pose.legSwing, time, h, pose);
  else if (h.heroId === 'otter') drawOtterBody(g, def, pose.bob, pose.legSwing, time, h, pose);
  else if (h.heroId === 'hedgehog') drawHedgehogBody(g, def, pose.bob, pose.legSwing, time, h, pose);
  else drawRabbitBody(g, def, pose.bob, pose.legSwing, time, h, pose);
}

function drawTigerBody(g, def, bob, legSwing, time, h, pose) {
  pose = pose || {};
  const atk = pose.atk || 0;
  const cast = pose.cast || 0;
  const hurt = pose.hurt || 0;
  const walk = pose.walkSin || 0;
  const seed = h.seed || 0;
  const blinkPhase = (time * 0.42 + seed * 0.31) % 1;
  const blink = blinkPhase < 0.045 ? Math.sin(blinkPhase / 0.045 * Math.PI) : 0;

  /* 尾巴：随步态和施法摆动 */
  const tailSway = Math.sin(time * 2.9 + seed) * 5 + walk * 4 - hurt * 5;
  const t0 = { x: -15, y: -27 };
  const t1 = { x: -40 + tailSway * 0.45, y: -34 + Math.abs(walk) * 2 };
  const t2 = { x: -39 + tailSway, y: -62 - cast * 4 };
  g.strokeStyle = def.fur;
  g.lineWidth = 9;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(t0.x, t0.y);
  g.quadraticCurveTo(t1.x, t1.y, t2.x, t2.y);
  g.stroke();
  g.fillStyle = def.furDark;
  [0.36, 0.58, 0.78].forEach(t => {
    const it = 1 - t;
    const x = it * it * t0.x + 2 * it * t * t1.x + t * t * t2.x;
    const y = it * it * t0.y + 2 * it * t * t1.y + t * t * t2.y;
    const dx = 2 * it * (t1.x - t0.x) + 2 * t * (t2.x - t1.x);
    const dy = 2 * it * (t1.y - t0.y) + 2 * t * (t2.y - t1.y);
    g.save();
    g.translate(x, y);
    g.rotate(Math.atan2(dy, dx) + Math.PI / 2);
    ellipse(g, 0, 0, 2.4, 5.6);
    g.fill();
    g.restore();
  });
  g.fillStyle = def.cream;
  ellipse(g, t2.x, t2.y, 6, 6);
  g.fill();

  /* 后腿 */
  g.save();
  g.translate(-10, -18);
  g.rotate(-legSwing * 0.055);
  g.fillStyle = def.furDark;
  roundRect(g, -6, 0, 12.5, 19, 6);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, 1, 18, 7, 4);
  g.fill();
  g.restore();

  /* 后手臂 */
  const backPawY = -22 - cast * 16 + Math.sin(time * 2.6 + seed) * 1.2;
  g.strokeStyle = def.furDark;
  g.lineWidth = 7.5;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(-17, -40);
  g.quadraticCurveTo(-27, -31, -24, backPawY);
  g.stroke();
  g.fillStyle = def.cream;
  ellipse(g, -24, backPawY, 5.4, 4.6);
  g.fill();

  /* 前腿 */
  g.save();
  g.translate(7, -18);
  g.rotate(legSwing * 0.06);
  g.fillStyle = def.fur;
  roundRect(g, -6, 0, 13, 19, 6);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, 1, 18, 7, 4.2);
  g.fill();
  g.restore();

  /* 身体 */
  const bg = g.createLinearGradient(0, -52, 0, -6);
  bg.addColorStop(0, def.fur);
  bg.addColorStop(1, '#ef9b44');
  g.fillStyle = bg;
  ellipse(g, 0, -30, 23, 22);
  g.fill();
  g.fillStyle = 'rgba(166,82,26,.16)';
  ellipse(g, -9, -20, 11, 8);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, 4, -25, 14, 13);
  g.fill();
  g.strokeStyle = 'rgba(190,105,40,.3)';
  g.lineWidth = 2;
  [[-6, -39], [-9, -33]].forEach(([x, y]) => {
    g.beginPath();
    g.moveTo(x, y);
    g.quadraticCurveTo(x - 5, y + 2, x - 8, y + 1);
    g.stroke();
  });

  /* 围巾 */
  const scarfWave = Math.sin(time * 4.2 + seed) * 3 + walk * 3 + cast * 4;
  g.fillStyle = def.accent;
  roundRect(g, -17, -48, 38, 11, 5);
  g.fill();
  g.beginPath();
  g.moveTo(-12, -42);
  g.quadraticCurveTo(-28, -38 + scarfWave, -35, -22 + scarfWave * 0.5);
  g.lineTo(-24, -26 + scarfWave * 0.3);
  g.lineTo(-16, -38);
  g.closePath();
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.22)';
  roundRect(g, -15, -46, 30, 3, 2);
  g.fill();

  /* 头：呼吸、施法抬头、出招压低 */
  g.save();
  g.translate(Math.sin(time * 1.8 + seed) * 0.5, Math.sin(time * 2.2 + seed) * 0.6 - cast * 2.4 + hurt * 1.6);
  g.rotate(-atk * 0.05);

  const hg = g.createLinearGradient(0, -82, 0, -40);
  hg.addColorStop(0, '#ffc478');
  hg.addColorStop(1, def.fur);
  g.fillStyle = hg;
  ellipse(g, 2, -62, 23, 21);
  g.fill();
  /* 耳朵 */
  fillBlobs(g, def.fur, [[-15, -76 + Math.sin(time * 2.3 + seed) * 0.6, 9.5, 9], [20, -75 - cast * 1.4, 9, 8.5]]);
  fillBlobs(g, '#ffd9d2', [[-15, -76 + Math.sin(time * 2.3 + seed) * 0.6, 5.4, 5], [20, -75 - cast * 1.4, 5, 4.6]]);
  /* 头顶条纹 */
  g.strokeStyle = def.furDark;
  g.lineWidth = 3;
  g.lineCap = 'round';
  [[-6, -78, -3, -70], [2, -80, 3, -72], [10, -78, 13, -70], [-20, -64, -14, -64], [-21, -57, -15, -58], [23, -64, 17, -64], [23, -57, 17, -58]].forEach(l => {
    g.beginPath();
    g.moveTo(l[0], l[1]);
    g.lineTo(l[2], l[3]);
    g.stroke();
  });
  /* 口鼻 */
  g.fillStyle = def.cream;
  ellipse(g, 6, -54, 12.5, 9.5);
  g.fill();
  g.fillStyle = '#f7a7a0';
  g.beginPath();
  g.moveTo(4, -58);
  g.lineTo(9, -58);
  g.lineTo(6.5, -55);
  g.closePath();
  g.fill();
  const mouth = atk > 0.35 || cast > 0.3 ? 2.2 : 1;
  g.strokeStyle = '#8a5a3a';
  g.lineWidth = 1.4;
  g.beginPath();
  g.moveTo(6.5, -55);
  g.quadraticCurveTo(4 - mouth, -51, 1, -53);
  g.moveTo(6.5, -55);
  g.quadraticCurveTo(9 + mouth, -51, 12, -53);
  g.stroke();
  /* 眼睛（会眨眼；出招时认真） */
  const eyeH = 5.2 * (1 - blink * 0.82);
  fillBlobs(g, '#4a2f24', [[-4, -64, 4.6, eyeH], [12, -64, 4.6, eyeH]]);
  if (blink < 0.55) {
    fillBlobs(g, '#fff', [[-5.5, -66, 1.8, 2.1], [10.5, -66, 1.8, 2.1]]);
    fillBlobs(g, 'rgba(255,255,255,.65)', [[-2.6, -62, 1, 1.2], [13.4, -62, 1, 1.2]]);
  }
  if (atk > 0.3 || cast > 0.25) {
    g.strokeStyle = 'rgba(122,72,38,.75)';
    g.lineWidth = 1.7;
    g.beginPath();
    g.moveTo(-9, -70); g.lineTo(-2, -68.5);
    g.moveTo(8, -68.5); g.lineTo(15, -70);
    g.stroke();
  }
  /* 腮红 */
  fillBlobs(g, 'rgba(255,150,140,.35)', [[-10, -55, 3.4, 2.3], [18, -55, 3.4, 2.3]]);
  g.restore();

  /* 前手臂：攻击时大幅前扑出爪 */
  const pawX = 14 + atk * 26 + cast * 2;
  const pawY = -30 - atk * 16 - cast * 14;
  g.strokeStyle = def.fur;
  g.lineWidth = 8;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(12, -36);
  g.quadraticCurveTo(18, -31 - atk * 4, pawX, pawY);
  g.stroke();
  g.fillStyle = def.cream;
  ellipse(g, pawX, pawY, 5.8, 5);
  g.fill();
  g.strokeStyle = 'rgba(150,95,60,.4)';
  g.lineWidth = 1.2;
  g.beginPath();
  g.moveTo(pawX - 2, pawY - 3);
  g.lineTo(pawX - 3, pawY + 1.5);
  g.moveTo(pawX + 2, pawY - 3);
  g.lineTo(pawX + 2.5, pawY + 1.5);
  g.stroke();

  /* 爪击弧光：三道斜向爪痕，用高饱和暖橙保证在浅草地上也读得清 */
  if (atk > 0.06) {
    const a = Math.min(1, atk * 1.35);
    g.save();
    g.translate(20, -50);
    g.rotate(-0.28);
    g.lineCap = 'round';
    for (let i = 0; i < 3; i++) {
      const ox = i * 9, oy = i * 3;
      /* 外层暖橙描边 */
      g.globalAlpha = a * (0.78 - i * 0.08);
      g.strokeStyle = 'rgba(255,158,64,.9)';
      g.lineWidth = 8.5 - i * 0.9;
      g.beginPath();
      g.moveTo(ox, oy - 24);
      g.quadraticCurveTo(24 + ox, oy - 6, 40 + ox, oy + 22);
      g.stroke();
      /* 内层高光 */
      g.globalAlpha = a * (0.95 - i * 0.07);
      g.strokeStyle = '#fff7da';
      g.lineWidth = 3.2 - i * 0.3;
      g.beginPath();
      g.moveTo(ox + 1, oy - 22);
      g.quadraticCurveTo(24 + ox, oy - 6, 38 + ox, oy + 20);
      g.stroke();
    }
    /* 爪尖星芒 */
    g.globalAlpha = a * 0.9;
    drawStar(g, 52, 16, 4, 8 + atk * 7, 3.2, -0.2, '#ffd47a');
    g.restore();
  }

  /* 施法掌心光球 */
  if (cast > 0.05) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = cast * 0.9;
    const ox = pawX + 2, oy = pawY - 9;
    const og = g.createRadialGradient(ox, oy, 1, ox, oy, 11 + cast * 10);
    og.addColorStop(0, 'rgba(255,255,230,.95)');
    og.addColorStop(0.5, 'rgba(255,215,130,.5)');
    og.addColorStop(1, 'rgba(255,200,110,0)');
    g.fillStyle = og;
    ellipse(g, ox, oy, 11 + cast * 10, 11 + cast * 10);
    g.fill();
    drawStar(g, ox, oy, 4, 4 + cast * 4, 1.8, time * 4, '#fff7d2');
    g.restore();
  }
}

function drawFoxBody(g, def, bob, legSwing, time, h, pose) {
  pose = pose || {};
  const atk = pose.atk || 0;
  const cast = pose.cast || 0;
  const hurt = pose.hurt || 0;
  const walk = pose.walkSin || 0;
  const seed = h.seed || 0;
  const blinkPhase = (time * 0.37 + seed * 0.43) % 1;
  const blink = blinkPhase < 0.045 ? Math.sin(blinkPhase / 0.045 * Math.PI) : 0;
  const sway = Math.sin(time * 2.6 + seed) * 4 + walk * 5 - hurt * 4;

  /* 大尾巴 */
  g.fillStyle = '#e8ab63';
  g.beginPath();
  g.moveTo(-12, -24);
  g.bezierCurveTo(-46 + sway * 0.35, -20, -58 + sway, -56 - cast * 3, -34 + sway * 1.15, -66 - cast * 5);
  g.bezierCurveTo(-20 + sway * 0.8, -70 - cast * 4, -8, -54, -14, -38);
  g.closePath();
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.16)';
  ellipse(g, -28 + sway * 0.5, -52, 7, 4.6, 0.5);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, -42 + sway * 1.15, -60 - cast * 5, 12, 11);
  g.fill();

  /* 斗篷：随步伐与施法摆动 */
  const flap = Math.sin(time * 3.1 + seed) * 2.2 + walk * 2.4 + cast * 5;
  const cape = g.createLinearGradient(0, -55, 0, -8);
  cape.addColorStop(0, '#8d6be0');
  cape.addColorStop(1, '#6a4bc0');
  g.fillStyle = cape;
  g.beginPath();
  g.moveTo(-15, -46);
  g.quadraticCurveTo(-33 - flap * 0.4, -30, -26 - flap * 0.7, -6);
  g.quadraticCurveTo(0, -2, 24 + flap * 0.3, -6);
  g.quadraticCurveTo(30 + flap * 0.3, -32, 13, -46);
  g.closePath();
  g.fill();
  g.strokeStyle = 'rgba(255,255,255,.22)';
  g.lineWidth = 1.6;
  g.stroke();
  g.fillStyle = 'rgba(255,255,255,.18)';
  drawStar(g, -18 - flap * 0.3, -34, 5, 3.5, 1.6, 0, 'rgba(255,255,255,.55)');
  drawStar(g, 17, -22 + flap * 0.2, 4, 2.6, 1.2, 0.2, 'rgba(255,255,255,.4)');

  /* 腿 */
  g.save();
  g.translate(-7, -14);
  g.rotate(-legSwing * 0.05);
  g.fillStyle = def.fur;
  roundRect(g, -5, 0, 10, 15, 5);
  g.fill();
  g.fillStyle = '#6d4a32';
  ellipse(g, 1, 14, 6, 3.4);
  g.fill();
  g.restore();
  g.save();
  g.translate(9, -14);
  g.rotate(legSwing * 0.05);
  g.fillStyle = def.fur;
  roundRect(g, -5, 0, 10, 15, 5);
  g.fill();
  g.fillStyle = '#6d4a32';
  ellipse(g, 1, 14, 6, 3.4);
  g.fill();
  g.restore();

  /* 后手臂 */
  g.strokeStyle = '#6a4bc0';
  g.lineWidth = 7;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(-12, -38);
  g.quadraticCurveTo(-21, -33, -19 + cast * 2, -23 - cast * 10);
  g.stroke();
  g.fillStyle = def.cream;
  ellipse(g, -19 + cast * 2, -22 - cast * 10, 4.6, 4.2);
  g.fill();

  /* 身体 */
  g.fillStyle = '#f4d6a6';
  ellipse(g, 2, -28, 19, 19);
  g.fill();
  g.fillStyle = 'rgba(214,158,97,.22)';
  ellipse(g, -7, -22, 8, 8);
  g.fill();
  g.fillStyle = '#fff5e1';
  ellipse(g, 5, -25, 11, 11);
  g.fill();
  /* 毛领 */
  fillBlobs(g, '#f2f8ee', [[-8, -45, 9, 6], [4, -47, 9, 6], [14, -44, 8, 5.5]]);

  /* 头 */
  g.save();
  g.translate(Math.sin(time * 1.9 + seed) * 0.5, Math.sin(time * 2.1 + seed) * 0.55 - cast * 2 + hurt * 1.4);
  g.rotate(-atk * 0.04 - cast * 0.04);

  g.fillStyle = def.fur;
  ellipse(g, 2, -59, 20, 18);
  g.fill();
  /* 耳朵 */
  const earWiggle = Math.sin(time * 2.2 + seed) * 1.4 - hurt * 2;
  g.fillStyle = def.fur;
  g.beginPath();
  g.moveTo(-14, -68); g.lineTo(-9 + earWiggle * 0.4, -88); g.lineTo(0, -71); g.closePath(); g.fill();
  g.beginPath();
  g.moveTo(9, -71); g.lineTo(18 + earWiggle * 0.5, -89); g.lineTo(21, -66); g.closePath(); g.fill();
  g.fillStyle = '#f4b8b0';
  g.beginPath();
  g.moveTo(-10, -71); g.lineTo(-8 + earWiggle * 0.3, -83); g.lineTo(-3, -72); g.closePath(); g.fill();
  g.beginPath();
  g.moveTo(12, -72); g.lineTo(17 + earWiggle * 0.3, -83); g.lineTo(18, -69); g.closePath(); g.fill();

  /* 巫师帽（轻轻晃动） */
  g.save();
  const hatTilt = Math.sin(time * 1.7 + seed) * 0.035 + cast * 0.05;
  g.translate(2, -70);
  g.rotate(hatTilt);
  g.translate(-2, 70);
  g.fillStyle = '#7d5cd6';
  g.beginPath();
  g.moveTo(-19, -71);
  g.quadraticCurveTo(-14, -86, -6, -100);
  g.quadraticCurveTo(4, -112, 16, -96);
  g.quadraticCurveTo(8, -94, 4, -84);
  g.quadraticCurveTo(10, -78, 20, -70);
  g.closePath();
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.14)';
  g.beginPath();
  g.moveTo(-8, -80);
  g.quadraticCurveTo(-2, -94, 8, -101);
  g.quadraticCurveTo(4, -92, -2, -79);
  g.closePath();
  g.fill();
  g.fillStyle = '#6947c2';
  ellipse(g, 2, -70, 23, 7);
  g.fill();
  drawStar(g, 12, -90, 4, 4.6, 2, 0, '#ffe39a');
  drawStar(g, -8, -82, 4, 3, 1.3, 0, '#ffe39a');
  g.restore();

  /* 脸 */
  g.fillStyle = def.cream;
  ellipse(g, 5, -54, 10.5, 7.6);
  g.fill();
  g.fillStyle = '#6d4a3b';
  ellipse(g, 6, -56, 2.6, 2);
  g.fill();
  g.strokeStyle = '#6d4a3b';
  g.lineWidth = 1.3;
  g.beginPath();
  g.moveTo(6, -55);
  g.quadraticCurveTo(3.5, -51.5, 1.5, -53);
  g.moveTo(6, -55);
  g.quadraticCurveTo(8.5, -51.5, 10.5, -53);
  g.stroke();
  const eyeH = 4.8 * (1 - blink * 0.82);
  fillBlobs(g, '#4a2f24', [[-5, -61, 4.3, eyeH], [12, -61, 4.3, eyeH]]);
  if (blink < 0.55) {
    fillBlobs(g, '#fff', [[-6.2, -63, 1.7, 2], [10.8, -63, 1.7, 2]]);
  }
  if (atk > 0.3 || cast > 0.25) {
    g.strokeStyle = 'rgba(92,58,40,.7)';
    g.lineWidth = 1.5;
    g.beginPath();
    g.moveTo(-9, -68); g.lineTo(-2, -66.5);
    g.moveTo(8, -66.5); g.lineTo(15, -68);
    g.stroke();
  }
  fillBlobs(g, 'rgba(255,150,140,.32)', [[-11, -53, 3.2, 2.2], [18, -53, 3.2, 2.2]]);
  g.restore();

  /* 星星魔杖（攻击前刺、施法举起） */
  const staffX = 23 + atk * 15 - cast * 4;
  const staffY = -26 - cast * 18 + Math.sin(time * 2 + seed) * 1.1;
  const staffRot = -0.7 + atk * 1.1 - cast * 0.8;
  g.save();
  g.translate(staffX, staffY);
  g.rotate(staffRot);
  g.strokeStyle = '#c9a36b';
  g.lineWidth = 3.4;
  g.lineCap = 'round';
  g.beginPath(); g.moveTo(0, 17); g.lineTo(0, -13); g.stroke();
  g.strokeStyle = 'rgba(255,255,255,.34)';
  g.lineWidth = 1.2;
  g.beginPath(); g.moveTo(-1.2, 13); g.lineTo(-1.2, -7); g.stroke();
  const glowP = Math.max(cast, atk * 0.35);
  if (glowP > 0.04) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = 0.35 + glowP * 0.65;
    const sg = g.createRadialGradient(0, -18, 1, 0, -18, 12 + glowP * 12);
    sg.addColorStop(0, 'rgba(255,250,210,.95)');
    sg.addColorStop(0.5, 'rgba(255,214,120,.5)');
    sg.addColorStop(1, 'rgba(255,200,100,0)');
    g.fillStyle = sg;
    ellipse(g, 0, -18, 12 + glowP * 12, 12 + glowP * 12);
    g.fill();
    g.restore();
  }
  drawStar(g, 0, -18, 5, 7 + glowP * 2.4, 3 + glowP * 1.1, time * 0.8, '#ffe07a');
  drawStar(g, 0, -18, 4, 3.4 + glowP * 1.4, 1.4, -time * 1.2, '#fff8d6');
  g.restore();

  /* 前手臂：握住魔杖 */
  const handX = staffX - 3 + Math.cos(staffRot) * 1;
  const handY = staffY + 2 + Math.sin(staffRot) * 1;
  g.strokeStyle = '#7d5cd6';
  g.lineWidth = 7;
  g.beginPath();
  g.moveTo(11, -38);
  g.quadraticCurveTo(18, -33 + atk * 2, handX, handY);
  g.stroke();
  g.fillStyle = def.cream;
  ellipse(g, handX, handY, 4.8, 4.4);
  g.fill();

  /* 施法环绕星点 */
  if (cast > 0.08) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = cast * 0.8;
    for (let i = 0; i < 4; i++) {
      const a = time * 4 + i * TAU / 4;
      drawStar(g, Math.cos(a) * 31, -48 + Math.sin(a) * 15, 4, 3.4 + cast * 2, 1.3, a, '#fff2b8');
    }
    g.restore();
  }

  /* 挥杖星轨：紫金弧光，在浅色草地上也能读出挥击方向 */
  if (atk > 0.1) {
    const a = Math.min(1, atk * 1.3);
    g.save();
    g.translate(26, -36);
    g.lineCap = 'round';
    g.globalAlpha = a * 0.5;
    g.strokeStyle = 'rgba(186,136,255,.85)';
    g.lineWidth = 10;
    g.beginPath();
    g.arc(0, 0, 32, -1.45, 0.45);
    g.stroke();
    g.globalAlpha = a * 0.95;
    g.strokeStyle = 'rgba(255,232,140,.95)';
    g.lineWidth = 3.6;
    g.beginPath();
    g.arc(0, 0, 27, -1.25, 0.4);
    g.stroke();
    g.globalAlpha = a;
    for (let i = 0; i < 3; i++) {
      const ang = -1.05 + i * 0.5;
      drawStar(g, Math.cos(ang) * 31, Math.sin(ang) * 31, 4, 3.4 + atk * 2, 1.4, ang, '#fff3c2');
    }
    drawStar(g, 32, 2, 4, 8 + atk * 6, 3.2, -0.2, '#ffe08a');
    g.restore();
  }
}

function drawRabbitBody(g, def, bob, legSwing, time, h, pose) {
  pose = pose || {};
  const atk = pose.atk || 0;
  const cast = pose.cast || 0;
  const hurt = pose.hurt || 0;
  const walk = pose.walkSin || 0;
  const seed = h.seed || 0;
  const blinkPhase = (time * 0.45 + seed * 0.27) % 1;
  const blink = blinkPhase < 0.045 ? Math.sin(blinkPhase / 0.045 * Math.PI) : 0;

  /* 长耳朵：风吹 + 施法竖起 */
  const earSway = Math.sin(time * 2.1 + seed) * 0.055 + walk * 0.05 - hurt * 0.16 + cast * 0.03;
  g.fillStyle = '#fffaf7';
  ellipse(g, -8 + cast * 2, -94, 7.5, 21 + cast * 1.5, -0.12 + earSway);
  g.fill();
  ellipse(g, 12 + cast * 2, -95, 7.5, 22 + cast * 1.2, 0.16 - earSway * 0.8);
  g.fill();
  g.fillStyle = '#ffd6dd';
  ellipse(g, -8 + cast * 2, -94, 4.2, 15 + cast, -0.12 + earSway);
  g.fill();
  ellipse(g, 12 + cast * 2, -95, 4.2, 16 + cast, 0.16 - earSway * 0.8);
  g.fill();
  /* 耳尖小光 */
  g.fillStyle = 'rgba(255,255,255,.8)';
  ellipse(g, -9 + cast * 2, -108, 2.4, 3.4, -0.12 + earSway);
  ellipse(g, 13 + cast * 2, -109, 2.2, 3.2, 0.16 - earSway * 0.8);

  /* 裙摆 */
  const skirtWave = Math.sin(time * 2.4 + seed) * 2.6 + walk * 2.5 + cast * 3;
  const skirt = g.createLinearGradient(0, -40, 0, -4);
  skirt.addColorStop(0, '#ffd9e4');
  skirt.addColorStop(1, '#f7a8c1');
  g.fillStyle = skirt;
  g.beginPath();
  g.moveTo(-13, -36);
  g.quadraticCurveTo(-26 - skirtWave, -14, -20 - skirtWave * 0.5, -4);
  g.quadraticCurveTo(0, 4 + skirtWave * 0.3, 22 + skirtWave * 0.5, -4);
  g.quadraticCurveTo(26 + skirtWave, -16, 12, -36);
  g.closePath();
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.55)';
  g.beginPath();
  g.moveTo(-6, -32);
  g.quadraticCurveTo(-9 - skirtWave * 0.3, -12, -5, -4);
  g.quadraticCurveTo(2, -2, 8, -4);
  g.quadraticCurveTo(8, -18, 5, -32);
  g.closePath();
  g.fill();
  g.fillStyle = '#a8e2c4';
  roundRect(g, -18, -40, 36, 8, 4);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.35)';
  roundRect(g, -15, -38, 26, 2.4, 1.2);
  g.fill();

  /* 脚 */
  fillBlobs(g, '#fffaf7', [[-11 + legSwing, -1, 7, 4], [12 - legSwing, -1, 7, 4]]);
  g.fillStyle = 'rgba(246,178,196,.45)';
  ellipse(g, -11 + legSwing, -1, 3.4, 1.8);
  g.fill();
  ellipse(g, 12 - legSwing, -1, 3.4, 1.8);
  g.fill();

  /* 身体 */
  g.fillStyle = '#fffaf7';
  ellipse(g, 1, -34, 17, 17);
  g.fill();
  g.fillStyle = 'rgba(246,210,220,.35)';
  ellipse(g, -7, -30, 7, 10);
  g.fill();
  g.fillStyle = '#ffd9e4';
  ellipse(g, 3, -30, 10, 10);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.6)';
  ellipse(g, 1, -37, 6, 3.4);
  g.fill();

  /* 头：呼吸与施法时轻仰 */
  g.save();
  g.translate(Math.sin(time * 2 + seed) * 0.4, Math.sin(time * 2.3 + seed) * 0.55 - cast * 2.6 + hurt * 1.4);
  g.rotate(-atk * 0.03 - cast * 0.05);

  g.fillStyle = '#fffaf7';
  ellipse(g, 2, -60, 21, 19);
  g.fill();
  /* 花环 */
  const petals = ['#ffb8c9', '#fff0b8', '#cda9ff', '#a8e2c4'];
  for (let i = 0; i < 7; i++) {
    const a = Math.PI + (i / 6) * Math.PI;
    const px = 2 + Math.cos(a) * 19, py = -67 + Math.sin(a) * 15;
    g.fillStyle = petals[i % petals.length];
    ellipse(g, px, py, 4.4, 3.4, a);
    g.fill();
    g.fillStyle = '#f6c85a';
    ellipse(g, px, py, 1.6, 1.6);
    g.fill();
  }
  /* 眼睛（眨眼） */
  const eyeH = 5.4 * (1 - blink * 0.82);
  fillBlobs(g, '#5a3a35', [[-5, -61, 4.6, eyeH], [11, -61, 4.6, eyeH]]);
  if (blink < 0.55) {
    fillBlobs(g, '#fff', [[-6.4, -63.2, 1.8, 2.2], [9.6, -63.2, 1.8, 2.2]]);
    fillBlobs(g, 'rgba(255,255,255,.7)', [[-3.6, -59, 1, 1.2], [12.4, -59, 1, 1.2]]);
  }
  /* 鼻子 & 嘴 */
  g.fillStyle = '#f39aa9';
  g.beginPath();
  g.moveTo(1, -53);
  g.lineTo(5, -53);
  g.lineTo(3, -50.5);
  g.closePath();
  g.fill();
  const smile = atk > 0.3 || cast > 0.25 ? 1.6 : 1;
  g.strokeStyle = '#c98a94';
  g.lineWidth = 1.2;
  g.beginPath();
  g.moveTo(3, -50.5);
  g.quadraticCurveTo(1.5 - smile, -48, 0, -49.2);
  g.moveTo(3, -50.5);
  g.quadraticCurveTo(4.5 + smile, -48, 6, -49.2);
  g.stroke();
  /* 腮红 */
  fillBlobs(g, 'rgba(255,150,170,.35)', [[-11, -55, 3.6, 2.4], [17, -55, 3.6, 2.4]]);
  g.restore();

  /* 手臂：射星星时前伸，施法时举起 */
  const armLift = cast * 22;
  const pawL = { x: -16 - cast * 5, y: -20 - armLift };
  const pawR = { x: 18 + atk * 26 + cast * 4, y: -20 - armLift - atk * 14 };
  g.strokeStyle = '#fffaf7';
  g.lineWidth = 7;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(-13, -34);
  g.quadraticCurveTo(-20 - cast * 4, -27 - armLift * 0.4, pawL.x, pawL.y);
  g.stroke();
  g.beginPath();
  g.moveTo(16, -34);
  g.quadraticCurveTo(22 + atk * 6, -27 - armLift * 0.4, pawR.x, pawR.y);
  g.stroke();
  g.fillStyle = '#fffaf7';
  ellipse(g, pawL.x, pawL.y, 4.8, 4.4);
  g.fill();
  ellipse(g, pawR.x, pawR.y, 4.8, 4.4);
  g.fill();
  g.fillStyle = 'rgba(246,178,196,.5)';
  ellipse(g, pawL.x, pawL.y, 2.2, 1.7);
  g.fill();
  ellipse(g, pawR.x, pawR.y, 2.2, 1.7);
  g.fill();

  /* 星星小飞镖 */
  const sparkP = Math.max(atk * 1.2, cast);
  if (sparkP > 0.06) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = Math.min(1, sparkP) * 0.8;
    const sx = pawR.x + 6 + atk * 6;
    const sy = pawR.y - 3 - cast * 4;
    const sg = g.createRadialGradient(sx, sy, 1, sx, sy, 7 + sparkP * 7);
    sg.addColorStop(0, 'rgba(255,255,226,.95)');
    sg.addColorStop(0.5, 'rgba(255,224,140,.45)');
    sg.addColorStop(1, 'rgba(255,210,120,0)');
    g.fillStyle = sg;
    ellipse(g, sx, sy, 7 + sparkP * 7, 7 + sparkP * 7);
    g.fill();
    drawStar(g, sx, sy, 4, 4 + sparkP * 3.4, 1.7, time * 5, '#fff7d2');
    g.restore();
  }

  /* 施法花瓣与光点 */
  if (cast > 0.08) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = cast * 0.8;
    for (let i = 0; i < 5; i++) {
      const a = time * 2.6 + i * 1.6;
      const px = Math.cos(a) * (24 + i * 3);
      const py = -42 + Math.sin(a * 1.3) * 18;
      drawStar(g, px, py, 4, 2.6 + cast * 2, 1.1, a, i % 2 ? '#fff3b8' : '#d9ffe8');
    }
    g.restore();
  }

  /* 扔星镖时的弧形拖尾 */
  if (atk > 0.12) {
    const a = Math.min(1, atk * 1.3);
    g.save();
    g.lineCap = 'round';
    g.globalAlpha = a * 0.5;
    g.strokeStyle = 'rgba(255,150,196,.85)';
    g.lineWidth = 9;
    g.beginPath();
    g.arc(pawR.x + 16, pawR.y - 2, 26, -1.35, 0.45);
    g.stroke();
    g.globalAlpha = a * 0.95;
    g.strokeStyle = 'rgba(255,240,158,.95)';
    g.lineWidth = 3.4;
    g.beginPath();
    g.arc(pawR.x + 16, pawR.y - 2, 21, -1.15, 0.4);
    g.stroke();
    g.globalAlpha = a;
    drawStar(g, pawR.x + 42, pawR.y + 2, 4, 6 + atk * 4, 2.4, -0.2, '#ffe9a0');
    g.restore();
  }
}

function drawBearBody(g, def, bob, legSwing, time, h, pose) {
  pose = pose || {};
  const atk = pose.atk || 0;
  const cast = pose.cast || 0;
  const hurt = pose.hurt || 0;
  const walk = pose.walkSin || 0;
  const seed = h.seed || 0;
  const blinkPhase = (time * 0.4 + seed * 0.27) % 1;
  const blink = blinkPhase < 0.045 ? Math.sin(blinkPhase / 0.045 * Math.PI) : 0;

  /* 小圆尾巴：随步态轻晃 */
  const tailWag = Math.sin(time * 2.5 + seed) * 1.5 + walk * 2.2 - hurt * 2;
  g.fillStyle = def.furDark;
  ellipse(g, -27, -16 + tailWag * 0.5, 6.5, 6);
  g.fill();

  /* 后腿：粗短，重心压低 */
  g.save();
  g.translate(-12, -14);
  g.rotate(-legSwing * 0.045);
  g.fillStyle = def.furDark;
  roundRect(g, -8.5, 0, 17, 15, 8);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, 1, 14, 8, 4);
  g.fill();
  g.restore();

  /* 后手臂：空手摆动 */
  const backPawY = -18 - cast * 10 + Math.sin(time * 2.4 + seed) * 1.1;
  g.strokeStyle = def.furDark;
  g.lineWidth = 8.5;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(-18, -34);
  g.quadraticCurveTo(-28, -27, -25, backPawY);
  g.stroke();
  g.fillStyle = def.cream;
  ellipse(g, -25, backPawY, 5.6, 4.8);
  g.fill();

  /* 前腿 */
  g.save();
  g.translate(10, -14);
  g.rotate(legSwing * 0.05);
  g.fillStyle = def.fur;
  roundRect(g, -8.5, 0, 17, 15, 8);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, 1, 14, 8, 4.2);
  g.fill();
  g.restore();

  /* 身体：圆胖厚重，最矮最宽 */
  const bg = g.createLinearGradient(0, -48, 0, -4);
  bg.addColorStop(0, def.fur);
  bg.addColorStop(1, def.furDark);
  g.fillStyle = bg;
  ellipse(g, 0, -26, 26, 23);
  g.fill();
  g.fillStyle = 'rgba(90,55,30,.14)';
  ellipse(g, -12, -16, 11, 8);
  g.fill();
  /* 奶油大肚皮 */
  g.fillStyle = def.cream;
  ellipse(g, 5, -22, 15, 14);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.32)';
  ellipse(g, 3, -30, 6.5, 3.4);
  g.fill();

  /* 草绿小围巾：飘带垂在身后 */
  const scarfWave = Math.sin(time * 3.8 + seed) * 2.6 + walk * 3 + cast * 3;
  g.fillStyle = def.accent;
  roundRect(g, -16, -44, 34, 10, 5);
  g.fill();
  g.beginPath();
  g.moveTo(-11, -38);
  g.quadraticCurveTo(-26, -34 + scarfWave, -32, -20 + scarfWave * 0.5);
  g.lineTo(-22, -24 + scarfWave * 0.3);
  g.lineTo(-15, -34);
  g.closePath();
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.2)';
  roundRect(g, -14, -42, 26, 2.6, 1.4);
  g.fill();

  /* 头：大而圆，施法轻抬、出招前压、受击后仰 */
  g.save();
  g.translate(Math.sin(time * 1.6 + seed) * 0.5 + atk * 2, Math.sin(time * 2 + seed) * 0.6 - cast * 2.2 + hurt * 1.8);
  g.rotate(-atk * 0.04 - hurt * 0.05);

  const hg = g.createLinearGradient(0, -84, 0, -42);
  hg.addColorStop(0, '#cf9a6d');
  hg.addColorStop(1, def.fur);
  g.fillStyle = hg;
  ellipse(g, 3, -62, 22, 20);
  g.fill();
  /* 小圆耳朵 */
  const earBob = Math.sin(time * 2.4 + seed) * 0.6;
  fillBlobs(g, def.fur, [[-14, -78 + earBob, 8, 7.6], [20, -77 + earBob, 8, 7.6]]);
  fillBlobs(g, def.furDark, [[-14, -78 + earBob, 4.6, 4.2], [20, -77 + earBob, 4.6, 4.2]]);
  /* 口鼻 */
  g.fillStyle = def.cream;
  ellipse(g, 7, -53, 12, 9);
  g.fill();
  g.fillStyle = '#6b4a33';
  ellipse(g, 7, -56.5, 3.4, 2.6);
  g.fill();
  const mouth = atk > 0.3 || cast > 0.3 ? 1.8 : 1;
  g.strokeStyle = '#7a5238';
  g.lineWidth = 1.4;
  g.beginPath();
  g.moveTo(7, -54.5);
  g.quadraticCurveTo(5 - mouth, -50.5, 2, -52);
  g.moveTo(7, -54.5);
  g.quadraticCurveTo(9 + mouth, -50.5, 12, -52);
  g.stroke();
  /* 眼睛（会眨眼；出招时皱眉） */
  const eyeH = 4.8 * (1 - blink * 0.82);
  fillBlobs(g, '#3f2a1e', [[-4, -64, 4.4, eyeH], [13, -64, 4.4, eyeH]]);
  if (blink < 0.55) {
    fillBlobs(g, '#fff', [[-5.3, -65.8, 1.7, 2], [11.7, -65.8, 1.7, 2]]);
    fillBlobs(g, 'rgba(255,255,255,.6)', [[-2.6, -62.2, 1, 1.1], [14.4, -62.2, 1, 1.1]]);
  }
  if (atk > 0.3 || cast > 0.25) {
    g.strokeStyle = 'rgba(90,55,30,.8)';
    g.lineWidth = 2;
    g.beginPath();
    g.moveTo(-9, -70.5); g.lineTo(-1, -68.5);
    g.moveTo(9, -68.5); g.lineTo(17, -70.5);
    g.stroke();
  }
  fillBlobs(g, 'rgba(255,150,130,.28)', [[-12, -55, 3.4, 2.2], [19, -55, 3.4, 2.2]]);
  g.restore();

  /* 前手臂：举盾的手 */
  const armX = 16 + atk * 12;
  const armY = -28 - cast * 8;
  g.strokeStyle = def.fur;
  g.lineWidth = 9;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(14, -32);
  g.quadraticCurveTo(20, -30, armX, armY);
  g.stroke();

  /* 荷叶盾：出招前推、随步态轻晃 */
  const shieldX = 30 + atk * 15 - hurt * 8;
  const shieldY = -32 - cast * 6 + Math.sin(time * 2.2 + seed) * 1;
  const shieldRot = Math.sin(time * 1.9 + seed) * 0.05 + walk * 0.09 - hurt * 0.14 - atk * 0.1;
  g.save();
  g.translate(shieldX, shieldY);
  g.rotate(shieldRot);
  const lg = g.createRadialGradient(-4, -4, 3, 0, 0, 24);
  lg.addColorStop(0, def.accent);
  lg.addColorStop(1, '#3c6b41');
  g.fillStyle = lg;
  g.beginPath();
  for (let i = 0; i <= 22; i++) {
    const a = (i / 22) * TAU;
    const rr = 17 + Math.sin(a * 6) * 2.2;
    const px = Math.cos(a) * rr;
    const py = Math.sin(a) * rr * 0.94;
    if (i === 0) g.moveTo(px, py); else g.lineTo(px, py);
  }
  g.closePath();
  g.fill();
  /* 荷叶脉纹 */
  g.strokeStyle = 'rgba(255,255,255,.28)';
  g.lineWidth = 1.3;
  for (let i = 0; i < 5; i++) {
    const a = -1.9 + i * 0.95;
    g.beginPath();
    g.moveTo(0, 0);
    g.lineTo(Math.cos(a) * 14, Math.sin(a) * 14);
    g.stroke();
  }
  g.fillStyle = 'rgba(255,255,255,.16)';
  ellipse(g, -5, -6, 7, 4.4, 0.5);
  g.fill();
  /* 爪子抓住盾背 */
  g.fillStyle = def.cream;
  ellipse(g, 2, 11, 5.2, 4.4);
  g.fill();
  g.restore();

  /* 盾击弧光：暖橙外圈 + 金色芯，保证浅草地上读得出前推方向 */
  if (atk > 0.06) {
    const a = Math.min(1, atk * 1.35);
    g.save();
    g.translate(42, -40);
    g.lineCap = 'round';
    g.globalAlpha = a * 0.55;
    g.strokeStyle = 'rgba(255,170,70,.9)';
    g.lineWidth = 10;
    g.beginPath();
    g.arc(-8, 0, 24, -0.95, 0.85);
    g.stroke();
    g.globalAlpha = a * 0.95;
    g.strokeStyle = '#ffdf92';
    g.lineWidth = 3.6;
    g.beginPath();
    g.arc(-8, 0, 19, -0.8, 0.72);
    g.stroke();
    g.globalAlpha = a;
    drawStar(g, 18, 10, 4, 7 + atk * 6, 3, 0.3, '#ffd47a');
    g.restore();
  }

  /* 施法：盾面浮起生命光球 */
  if (cast > 0.05) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = cast * 0.85;
    const og = g.createRadialGradient(shieldX, shieldY, 1, shieldX, shieldY, 12 + cast * 12);
    og.addColorStop(0, 'rgba(240,255,230,.95)');
    og.addColorStop(0.5, 'rgba(150,230,150,.45)');
    og.addColorStop(1, 'rgba(120,210,130,0)');
    g.fillStyle = og;
    ellipse(g, shieldX, shieldY, 12 + cast * 12, 12 + cast * 12);
    g.fill();
    drawStar(g, shieldX, shieldY, 4, 4 + cast * 4, 1.8, time * 4, '#f2ffdc');
    g.restore();
  }
}

function drawOtterBody(g, def, bob, legSwing, time, h, pose) {
  pose = pose || {};
  const atk = pose.atk || 0;
  const cast = pose.cast || 0;
  const hurt = pose.hurt || 0;
  const walk = pose.walkSin || 0;
  const seed = h.seed || 0;
  const blinkPhase = (time * 0.43 + seed * 0.37) % 1;
  const blink = blinkPhase < 0.045 ? Math.sin(blinkPhase / 0.045 * Math.PI) : 0;

  /* 扁平桨状大尾巴：识别特征，随步态与呼吸摆动 */
  const tailSway = Math.sin(time * 2.3 + seed) * 6 + walk * 6 - hurt * 5;
  g.save();
  g.translate(-14, -20);
  g.rotate(-0.32 + tailSway * 0.018);
  const tg = g.createLinearGradient(0, 0, -40, -14);
  tg.addColorStop(0, def.fur);
  tg.addColorStop(1, def.furDark);
  g.fillStyle = tg;
  g.beginPath();
  g.moveTo(0, -4);
  g.quadraticCurveTo(-18, -12, -32, -22 - tailSway * 0.25);
  g.quadraticCurveTo(-46, -18, -44, -6);
  g.quadraticCurveTo(-40, 3, -22, 3);
  g.quadraticCurveTo(-9, 3, 0, 5);
  g.closePath();
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.16)';
  ellipse(g, -31, -12, 8, 4, -0.35);
  g.fill();
  g.restore();

  /* 后腿 */
  g.save();
  g.translate(-8, -13);
  g.rotate(-legSwing * 0.06);
  g.fillStyle = def.furDark;
  roundRect(g, -5.5, 0, 11, 14, 5.5);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, 2, 13, 6.5, 3.4);
  g.fill();
  g.restore();

  /* 身体：流线偏瘦，站姿略前倾 */
  g.save();
  g.translate(0, Math.sin(time * 2.2 + seed) * 0.7);
  g.rotate(0.05 + cast * 0.02 - hurt * 0.07);
  const bg = g.createLinearGradient(0, -50, 0, -8);
  bg.addColorStop(0, def.fur);
  bg.addColorStop(1, def.furDark);
  g.fillStyle = bg;
  ellipse(g, 2, -28, 18, 21);
  g.fill();
  /* 奶油肚皮 */
  g.fillStyle = def.cream;
  ellipse(g, 7, -24, 11, 13);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.3)';
  ellipse(g, 4, -34, 5.5, 3);
  g.fill();

  /* 颈上一圈水草 */
  const grassWave = Math.sin(time * 3.2 + seed) * 2.4 + walk * 2.5 + cast * 3;
  g.strokeStyle = def.accent;
  g.lineWidth = 3.2;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(-13, -42);
  g.quadraticCurveTo(2, -37, 15, -43);
  g.stroke();
  g.fillStyle = def.accent;
  for (let i = 0; i < 4; i++) {
    const bx = -9 + i * 8;
    const by = -40 + Math.sin(i * 1.3) * 1.6;
    ellipse(g, bx, by, 3.6, 2.4, i * 0.5);
    g.fill();
  }
  /* 飘在身后的两茎水草 */
  g.strokeStyle = 'rgba(63,181,201,.8)';
  g.lineWidth = 2.2;
  g.beginPath();
  g.moveTo(-13, -42);
  g.quadraticCurveTo(-19, -33 + grassWave * 0.5, -17, -24 + grassWave * 0.4);
  g.moveTo(-11, -42);
  g.quadraticCurveTo(-23, -35 + grassWave, -25, -26 + grassWave * 0.5);
  g.stroke();
  g.restore();

  /* 头：小而圆，随动作轻仰 */
  g.save();
  g.translate(Math.sin(time * 1.9 + seed) * 0.5 + 2, Math.sin(time * 2.1 + seed) * 0.6 - cast * 2.2 + hurt * 1.5);
  g.rotate(-atk * 0.05 - hurt * 0.05);

  g.fillStyle = def.fur;
  ellipse(g, 6, -60, 18, 16.5);
  g.fill();
  /* 小圆耳朵 */
  const earBob = Math.sin(time * 2.6 + seed) * 0.7;
  fillBlobs(g, def.fur, [[-8, -73 + earBob, 6.2, 5.8], [18, -72 + earBob, 6, 5.6]]);
  fillBlobs(g, '#cfe4f2', [[-8, -73 + earBob, 3.4, 3.2], [18, -72 + earBob, 3.2, 3]]);
  /* 奶油口鼻 */
  g.fillStyle = def.cream;
  ellipse(g, 10, -54, 10, 7.5);
  g.fill();
  g.fillStyle = '#4a6a80';
  ellipse(g, 11, -56.5, 2.8, 2.2);
  g.fill();
  const mouth = atk > 0.3 || cast > 0.3 ? 1.6 : 1;
  g.strokeStyle = '#4d6272';
  g.lineWidth = 1.2;
  g.beginPath();
  g.moveTo(11, -55);
  g.quadraticCurveTo(9 - mouth, -51.5, 6.5, -52.6);
  g.moveTo(11, -55);
  g.quadraticCurveTo(13 + mouth, -51.5, 15.5, -52.6);
  g.stroke();
  /* 胡须 */
  g.strokeStyle = 'rgba(90,110,125,.5)';
  g.lineWidth = 1;
  g.beginPath();
  g.moveTo(15, -55); g.lineTo(22, -57);
  g.moveTo(15, -53); g.lineTo(22, -52);
  g.moveTo(4, -54); g.lineTo(-2, -56);
  g.stroke();
  /* 眼睛（眨眼；出招时认真） */
  const eyeH = 4.6 * (1 - blink * 0.82);
  fillBlobs(g, '#2f4858', [[0, -62, 4.2, eyeH], [14, -62, 4.2, eyeH]]);
  if (blink < 0.55) {
    fillBlobs(g, '#fff', [[-1, -63.8, 1.6, 1.9], [13, -63.8, 1.6, 1.9]]);
  }
  if (atk > 0.3 || cast > 0.25) {
    g.strokeStyle = 'rgba(50,80,100,.75)';
    g.lineWidth = 1.5;
    g.beginPath();
    g.moveTo(-4, -68); g.lineTo(3, -66.5);
    g.moveTo(11, -66.5); g.lineTo(18, -68);
    g.stroke();
  }
  fillBlobs(g, 'rgba(160,205,235,.35)', [[-4, -55, 3, 2], [20, -55, 3, 2]]);
  g.restore();

  /* 头顶漂浮的大水泡：随施法变大变亮、随时间轻浮 */
  const bubX = 5 + Math.sin(time * 1.2 + seed) * 2;
  const bubY = -92 + Math.sin(time * 1.7 + seed * 2) * 2.5 - cast * 3;
  const bubR = 9 + cast * 6 + Math.sin(time * 2.4 + seed) * 0.6;
  g.save();
  g.globalAlpha = 0.34 + cast * 0.4;
  const bgr = g.createRadialGradient(bubX - bubR * 0.3, bubY - bubR * 0.35, bubR * 0.2, bubX, bubY, bubR);
  bgr.addColorStop(0, 'rgba(255,255,255,.5)');
  bgr.addColorStop(0.7, 'rgba(150,225,240,.22)');
  bgr.addColorStop(1, 'rgba(63,181,201,.5)');
  g.fillStyle = bgr;
  ellipse(g, bubX, bubY, bubR, bubR);
  g.fill();
  g.globalAlpha = 0.75 + cast * 0.25;
  g.strokeStyle = 'rgba(255,255,255,.6)';
  g.lineWidth = 1.4;
  ellipse(g, bubX, bubY, bubR, bubR);
  g.stroke();
  g.fillStyle = 'rgba(255,255,255,.85)';
  ellipse(g, bubX - bubR * 0.4, bubY - bubR * 0.45, 2.4, 1.8, -0.6);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.5)';
  ellipse(g, bubX + bubR * 0.35, bubY + bubR * 0.3, 1.3, 1);
  g.fill();
  g.restore();

  /* 双手抱在身前搓水花：出招前探、施法抬起 */
  const rubX = 15 + atk * 24 + cast * 3 + Math.sin(time * 3.2 + seed) * 1;
  const rubY = -26 - cast * 12 - atk * 8;
  g.strokeStyle = def.furDark;
  g.lineWidth = 6.2;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(-5, -34);
  g.quadraticCurveTo(5, -24, rubX - 4, rubY + 2);
  g.stroke();
  g.strokeStyle = def.fur;
  g.beginPath();
  g.moveTo(12, -34);
  g.quadraticCurveTo(20, -26, rubX, rubY);
  g.stroke();
  fillBlobs(g, def.cream, [[rubX - 4, rubY + 2, 4.4, 4], [rubX, rubY, 4.6, 4.2]]);

  /* 水鞭抽击弧光：高饱和青蓝外圈 + 暖金芯 */
  if (atk > 0.06) {
    const a = Math.min(1, atk * 1.35);
    g.save();
    g.translate(24, -42);
    g.lineCap = 'round';
    g.globalAlpha = a * 0.55;
    g.strokeStyle = 'rgba(56,190,220,.95)';
    g.lineWidth = 9.5;
    g.beginPath();
    g.arc(0, 0, 27, -1.4, 0.5);
    g.stroke();
    g.globalAlpha = a * 0.95;
    g.strokeStyle = '#ffe9a8';
    g.lineWidth = 3.4;
    g.beginPath();
    g.arc(0, 0, 22, -1.25, 0.42);
    g.stroke();
    g.globalAlpha = a;
    for (let i = 0; i < 3; i++) {
      const ang = -1 + i * 0.55;
      fillBlobs(g, 'rgba(230,250,255,.85)', [[Math.cos(ang) * 30, Math.sin(ang) * 30, 2.2, 2.2]]);
    }
    drawStar(g, 30, 8, 4, 6 + atk * 5, 2.6, 0.2, '#cdefff');
    g.restore();
  }

  /* 施法：掌心水灵光球 */
  if (cast > 0.05) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = cast * 0.9;
    const ox = rubX, oy = rubY - 5;
    const og = g.createRadialGradient(ox, oy, 1, ox, oy, 9 + cast * 9);
    og.addColorStop(0, 'rgba(235,255,255,.95)');
    og.addColorStop(0.5, 'rgba(110,220,240,.5)');
    og.addColorStop(1, 'rgba(63,181,201,0)');
    g.fillStyle = og;
    ellipse(g, ox, oy, 9 + cast * 9, 9 + cast * 9);
    g.fill();
    for (let i = 0; i < 3; i++) {
      const a = time * 4.5 + i * 2.1;
      drawStar(g, ox + Math.cos(a) * 11, oy + Math.sin(a) * 8, 4, 2.6, 1.1, a, '#e6fbff');
    }
    g.restore();
  }
}

function drawHedgehogBody(g, def, bob, legSwing, time, h, pose) {
  pose = pose || {};
  const atk = pose.atk || 0;
  const cast = pose.cast || 0;
  const hurt = pose.hurt || 0;
  const walk = pose.walkSin || 0;
  const seed = h.seed || 0;
  const blinkPhase = (time * 0.46 + seed * 0.19) % 1;
  const blink = blinkPhase < 0.045 ? Math.sin(blinkPhase / 0.045 * Math.PI) : 0;

  /* 背上放射状尖刺：出招向前炸开、施法竖起 */
  const flare = Math.max(0, atk) * 0.45 + cast * 0.35;
  const breathe = Math.sin(time * 2.2 + seed) * 0.03;
  const spikeHot = atk > 0.06 || cast > 0.15;
  for (let i = 0; i < 6; i++) {
    const t = i / 5;
    const a = -Math.PI * (0.93 - t * 0.48) + flare * 0.32 + breathe;
    const len = 15 + cast * 2.5 + Math.abs(atk) * 2;
    const sx = Math.cos(a) * 12, sy = -29 + Math.sin(a) * 12;
    const tipX = Math.cos(a) * (12 + len), tipY = -29 + Math.sin(a) * (12 + len);
    const px = -Math.sin(a) * 3.6, py = Math.cos(a) * 3.6;
    g.fillStyle = i % 2 === 0 ? def.furDark : '#7c6248';
    g.beginPath();
    g.moveTo(sx - px, sy - py);
    g.lineTo(sx + px, sy + py);
    g.lineTo(tipX, tipY);
    g.closePath();
    g.fill();
    /* 刺尖：奶油高光，出招/施法时发亮 */
    g.fillStyle = spikeHot ? '#ffe08a' : def.cream;
    ellipse(g, tipX, tipY, 1.7, 1.7);
    g.fill();
  }

  /* 短腿 */
  g.save();
  g.translate(-8, -12);
  g.rotate(-legSwing * 0.07);
  g.fillStyle = def.furDark;
  roundRect(g, -4.5, 0, 9, 13, 4.5);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, 1.5, 12, 5.4, 3);
  g.fill();
  g.restore();
  g.save();
  g.translate(8, -12);
  g.rotate(legSwing * 0.07);
  g.fillStyle = def.fur;
  roundRect(g, -4.5, 0, 9, 13, 4.5);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, 1.5, 12, 5.4, 3);
  g.fill();
  g.restore();

  /* 后手臂 */
  const backPawY = -17 - cast * 8 + Math.sin(time * 2.8 + seed) * 0.9;
  g.strokeStyle = def.furDark;
  g.lineWidth = 5.6;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(-10, -30);
  g.quadraticCurveTo(-16, -25, -14, backPawY);
  g.stroke();
  g.fillStyle = def.cream;
  ellipse(g, -14, backPawY, 4, 3.6);
  g.fill();

  /* 小小的身体 */
  const bg = g.createLinearGradient(0, -44, 0, -8);
  bg.addColorStop(0, def.fur);
  bg.addColorStop(1, def.furDark);
  g.fillStyle = bg;
  ellipse(g, 0, -29, 16, 16);
  g.fill();
  g.fillStyle = def.cream;
  ellipse(g, 5, -25, 9, 10);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.3)';
  ellipse(g, 3, -33, 4.6, 2.6);
  g.fill();

  /* 珊瑚红小背带（斜挎） */
  g.strokeStyle = def.accent;
  g.lineWidth = 4.4;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(-7, -41);
  g.quadraticCurveTo(2, -31, 11, -18);
  g.stroke();
  g.fillStyle = '#b0483f';
  ellipse(g, 11, -17, 2.6, 2.6);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.3)';
  ellipse(g, 0, -33, 1.8, 1.2, 0.6);
  g.fill();

  /* 头：圆滚滚，出招压低瞄准 */
  g.save();
  g.translate(Math.sin(time * 2 + seed) * 0.45 + atk * 2, Math.sin(time * 2.4 + seed) * 0.5 - cast * 2 + hurt * 1.4);
  g.rotate(-atk * 0.06 - hurt * 0.05);

  g.fillStyle = def.fur;
  ellipse(g, 6, -55, 15, 14);
  g.fill();
  /* 小圆耳朵 */
  const earBob = Math.sin(time * 2.5 + seed) * 0.6;
  fillBlobs(g, def.furDark, [[-3, -66 + earBob, 4.6, 4.4], [14, -67 + earBob, 4.4, 4.2]]);
  /* 尖尖的圆鼻子口鼻 */
  g.fillStyle = def.cream;
  ellipse(g, 13, -51, 8, 6);
  g.fill();
  g.fillStyle = '#5a4034';
  ellipse(g, 19, -52, 2.6, 2.2);
  g.fill();
  const smile = atk > 0.3 || cast > 0.25 ? 1.4 : 1;
  g.strokeStyle = '#8a6a52';
  g.lineWidth = 1.2;
  g.beginPath();
  g.moveTo(19, -50.5);
  g.quadraticCurveTo(17 - smile, -47.5, 15, -48.6);
  g.moveTo(19, -50.5);
  g.quadraticCurveTo(20.5 + smile * 0.5, -47.5, 22, -48.8);
  g.stroke();
  /* 小眼睛（眨眼） */
  const eyeH = 4.2 * (1 - blink * 0.82);
  fillBlobs(g, '#4a332a', [[3, -57, 3.8, eyeH], [13, -57, 3.8, eyeH]]);
  if (blink < 0.55) {
    fillBlobs(g, '#fff', [[2, -58.6, 1.5, 1.8], [12, -58.6, 1.5, 1.8]]);
  }
  if (atk > 0.3 || cast > 0.25) {
    g.strokeStyle = 'rgba(110,75,50,.75)';
    g.lineWidth = 1.5;
    g.beginPath();
    g.moveTo(-1, -62.5); g.lineTo(5, -61);
    g.moveTo(10, -61); g.lineTo(16, -62.5);
    g.stroke();
  }
  /* 脸颊腮红 */
  fillBlobs(g, 'rgba(255,150,140,.4)', [[-2, -50, 3.2, 2.2], [19, -46, 2.8, 2]]);
  g.restore();

  /* 前手臂：出招前伸瞄准、施法举起 */
  const handX = 15 + atk * 20 + cast * 3;
  const handY = -26 - cast * 12 - atk * 7 + Math.sin(time * 2.6 + seed) * 0.8;
  g.strokeStyle = def.fur;
  g.lineWidth = 5.8;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(8, -30);
  g.quadraticCurveTo(14, -28, handX, handY);
  g.stroke();
  g.fillStyle = def.cream;
  ellipse(g, handX, handY, 4.2, 3.8);
  g.fill();

  /* 棘刺齐射弧光：珊瑚红外圈 + 金色芯，附带一支飞出的刺 */
  if (atk > 0.06) {
    const a = Math.min(1, atk * 1.4);
    g.save();
    g.translate(22, -44);
    g.lineCap = 'round';
    g.globalAlpha = a * 0.55;
    g.strokeStyle = 'rgba(235,115,95,.95)';
    g.lineWidth = 8.5;
    g.beginPath();
    g.arc(0, 0, 26, -1.3, 0.5);
    g.stroke();
    g.globalAlpha = a * 0.95;
    g.strokeStyle = '#ffe08c';
    g.lineWidth = 3.2;
    g.beginPath();
    g.arc(0, 0, 21, -1.15, 0.42);
    g.stroke();
    g.globalAlpha = a;
    g.save();
    g.translate(36 + atk * 12, 4);
    g.rotate(0.25);
    g.fillStyle = def.furDark;
    g.beginPath();
    g.moveTo(-10, 2.4); g.lineTo(14, 0); g.lineTo(-10, -2.4);
    g.closePath();
    g.fill();
    g.fillStyle = '#ffd47a';
    ellipse(g, 14, 0, 2, 1.6);
    g.fill();
    g.restore();
    drawStar(g, 48 + atk * 12, 8, 4, 5 + atk * 4, 2, 0.3, '#ffcf7a');
    g.restore();
  }

  /* 施法：掌心凝聚暖金能量球 */
  if (cast > 0.05) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = cast * 0.9;
    const ox = handX + 3, oy = handY - 5;
    const og = g.createRadialGradient(ox, oy, 1, ox, oy, 8 + cast * 9);
    og.addColorStop(0, 'rgba(255,250,225,.95)');
    og.addColorStop(0.5, 'rgba(255,190,140,.5)');
    og.addColorStop(1, 'rgba(240,150,110,0)');
    g.fillStyle = og;
    ellipse(g, ox, oy, 8 + cast * 9, 8 + cast * 9);
    g.fill();
    drawStar(g, ox, oy, 4, 3.4 + cast * 3.4, 1.5, time * 5, '#fff3ce');
    g.restore();
  }
}

/* ============================================================
   小兵 / 塔 / 水晶 / 蜂蜜
   ============================================================ */
function drawMinionSprite(g, m, time) {
  if (!m.alive) return;
  const walkPhase = (m.walkT || 0) * 9.2 + m.seed;
  const moving = m.walkT > 0;
  const hop = moving ? Math.abs(Math.sin(walkPhase)) : Math.sin(time * 4.2 + m.seed) * 0.9;
  const atkP = m.atkAnim > 0 ? 1 - m.atkAnim / 0.22 : 0;
  const squash = 1 + (moving ? -Math.sin(walkPhase) * 0.04 : 0) + Math.sin(atkP * Math.PI) * 0.07;
  const bob = hop * 2.4;
  const r = m.big ? 23 : 16;
  const blinkPhase = (time * 0.55 + m.seed * 0.19) % 1;
  const blink = blinkPhase < 0.035 ? Math.sin(blinkPhase / 0.035 * Math.PI) : 0;

  g.save();
  g.translate(m.x, m.y);
  g.fillStyle = 'rgba(30,80,58,.2)';
  ellipse(g, 0, 2, (m.big ? 24 : 17) * (1 - hop * 0.03), (m.big ? 8 : 6) * (1 - hop * 0.03));
  g.fill();
  g.translate(0, -bob);
  g.rotate(moving ? Math.sin(walkPhase) * 0.05 : 0);
  g.scale(1 / squash, squash);

  const light = m.team === 'blue' ? '#8ceff0' : '#ffc4b4';
  const dark = m.team === 'blue' ? '#2f9fae' : '#e06a56';
  const body = g.createLinearGradient(0, -34, 0, 0);
  body.addColorStop(0, light);
  body.addColorStop(1, dark);
  g.fillStyle = body;
  ellipse(g, 0, -r + 2, r, r * 0.92);
  g.fill();

  /* 小叶子手臂 */
  const armWave = Math.sin(time * 3.4 + m.seed) * 1.6 + (moving ? Math.sin(walkPhase) * 2 : 0);
  g.strokeStyle = '#5aa97a';
  g.lineWidth = 2.2;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(-r * 0.82, -r * 0.5);
  g.quadraticCurveTo(-r * 1.18, -r * 0.65 + armWave, -r * 1.25, -r * 0.9 + armWave);
  g.stroke();
  g.beginPath();
  g.moveTo(r * 0.82, -r * 0.5);
  g.quadraticCurveTo(r * 1.18, -r * 0.65 - armWave, r * 1.25, -r * 0.9 - armWave);
  g.stroke();
  g.fillStyle = '#8edca2';
  ellipse(g, -r * 1.26, -r * 0.92 + armWave, 3.4, 2.2, -0.4);
  g.fill();
  ellipse(g, r * 1.26, -r * 0.92 - armWave, 3.4, 2.2, 0.4);
  g.fill();
  g.fillStyle = 'rgba(255,255,255,.35)';
  ellipse(g, -r * 0.35, -r * 0.9, r * 0.35, r * 0.22);
  g.fill();

  /* 嫩芽 */
  g.strokeStyle = '#4e9e6f';
  g.lineWidth = 2.4;
  g.beginPath();
  g.moveTo(0, -r * 2 + 3);
  g.quadraticCurveTo(2, -r * 2 - 8, 0, -r * 2 - 14);
  g.stroke();
  g.fillStyle = '#77c98e';
  ellipse(g, -5, -r * 2 - 12, 6, 3.4, -0.5);
  g.fill();
  ellipse(g, 5, -r * 2 - 16, 5, 3, 0.4);
  g.fill();

  /* 眼睛 */
  const er = m.big ? 3.4 : 2.7;
  fillBlobs(g, '#3d3b36', [[-r * 0.33, -r * 0.75, er, er * 1.15], [r * 0.33, -r * 0.75, er, er * 1.15]]);
  fillBlobs(g, '#fff', [[-r * 0.33 - 1, -r * 0.85, 1.1, 1.3], [r * 0.33 - 1, -r * 0.85, 1.1, 1.3]]);
  fillBlobs(g, 'rgba(255,255,255,.5)', [[-r * 0.6, -r * 0.45, 2.4, 1.6], [r * 0.6, -r * 0.45, 2.4, 1.6]]);
  fillBlobs(g, 'rgba(120,60,40,.35)', [[-r * 0.35, -r * 0.38, 2, 1.4], [r * 0.35, -r * 0.38, 2, 1.4]]);

  /* 大果冻的蘑菇帽 */
  if (m.big) {
    g.fillStyle = m.team === 'blue' ? '#4fb8c4' : '#e8765f';
    g.beginPath();
    g.ellipse(0, -r * 2 - 4, 24, 12, 0, Math.PI, TAU);
    g.closePath();
    g.fill();
    fillBlobs(g, 'rgba(255,255,255,.75)', [[-9, -r * 2 - 8, 3.6, 2.6], [7, -r * 2 - 11, 3, 2.2]]);
  }

  /* 小脚 */
  fillBlobs(g, dark, [[-r * 0.45, 1, r * 0.3, r * 0.16], [r * 0.45, 1, r * 0.3, r * 0.16]]);
  g.restore();
}

function drawTowerSprite(g, t, time) {
  const atkP = t.atkAnim > 0 ? 1 - t.atkAnim / 0.32 : 0;
  const recoil = Math.sin(atkP * Math.PI);
  const hitP = t.hitT > 0 ? Math.sin((1 - t.hitT / 0.2) * Math.PI) : 0;
  g.save();
  g.translate(t.x, t.y);
  g.rotate(recoil * 0.012 - hitP * 0.008);
  g.scale(0.84 * (1 + hitP * 0.03), 0.84 * (1 - recoil * 0.012));
  const tc = teamColor(t.team);
  const light = t.team === 'blue' ? '#8fe3ef' : '#ffb9a8';
  const dark = t.team === 'blue' ? '#2f9fae' : '#e06a56';

  /* 影子 & 土丘 */
  g.fillStyle = 'rgba(30,80,58,.2)';
  ellipse(g, 0, 6, 78, 24);
  g.fill();
  g.fillStyle = '#9bd0a0';
  ellipse(g, 0, 0, 72, 23);
  g.fill();
  g.fillStyle = '#bce2b2';
  ellipse(g, 0, -4, 62, 18);
  g.fill();
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * TAU;
    g.fillStyle = '#d5e9c4';
    ellipse(g, Math.cos(a) * 58, Math.sin(a) * 16 - 2, 5, 3);
    g.fill();
  }

  /* 塔身（蘑菇柄） */
  const stem = g.createLinearGradient(-28, 0, 28, 0);
  stem.addColorStop(0, '#f2e3c5');
  stem.addColorStop(0.55, '#fff8e8');
  stem.addColorStop(1, '#e8d4ae');
  g.fillStyle = stem;
  g.beginPath();
  g.moveTo(-30, -92);
  g.quadraticCurveTo(-26, -30, -34, -6);
  g.quadraticCurveTo(0, 8, 34, -6);
  g.quadraticCurveTo(26, -30, 30, -92);
  g.closePath();
  g.fill();
  g.strokeStyle = 'rgba(160,130,90,.25)';
  g.lineWidth = 2;
  g.stroke();

  /* 表情 */
  fillBlobs(g, '#4c3b2c', [[-11, -52, 3.6, 4.3], [11, -52, 3.6, 4.3]]);
  fillBlobs(g, 'rgba(255,255,255,.85)', [[-12, -53.5, 1.1, 1.4], [10, -53.5, 1.1, 1.4]]);
  g.strokeStyle = '#8b6a4a';
  g.lineWidth = 2;
  g.beginPath();
  g.arc(0, -46, 5, 0.2, Math.PI - 0.2);
  g.stroke();
  fillBlobs(g, 'rgba(255,150,140,.3)', [[-20, -46, 3.6, 2.2], [20, -46, 3.6, 2.2]]);

  /* 蘑菇帽 */
  const capGrad = g.createLinearGradient(0, -160, 0, -90);
  capGrad.addColorStop(0, light);
  capGrad.addColorStop(1, dark);
  g.fillStyle = capGrad;
  g.beginPath();
  g.moveTo(-64, -98);
  g.quadraticCurveTo(-60, -160, 0, -160);
  g.quadraticCurveTo(60, -160, 64, -98);
  g.quadraticCurveTo(30, -80, 0, -80);
  g.quadraticCurveTo(-30, -80, -64, -98);
  g.closePath();
  g.fill();
  g.strokeStyle = 'rgba(255,255,255,.45)';
  g.lineWidth = 3;
  g.stroke();
  fillBlobs(g, 'rgba(255,255,255,.78)', [[-30, -128, 10, 7], [3, -143, 7, 5], [33, -122, 9, 6], [-8, -110, 5, 3.6]]);
  /* 高光 */
  g.fillStyle = 'rgba(255,255,255,.25)';
  ellipse(g, -28, -145, 20, 7, -0.25);
  g.fill();

  /* 小旗 */
  g.strokeStyle = '#a98457';
  g.lineWidth = 3;
  g.beginPath();
  g.moveTo(0, -160);
  g.lineTo(0, -200);
  g.stroke();
  g.fillStyle = tc;
  g.beginPath();
  g.moveTo(0, -200);
  g.quadraticCurveTo(16 + Math.sin(time * 2) * 3, -196, 26, -188);
  g.quadraticCurveTo(12, -182, 0, -185);
  g.closePath();
  g.fill();
  drawStar(g, 2, -191, 4, 3, 1.2, 0, 'rgba(255,255,255,.9)');

  /* 保护泡泡 */
  if (isTowerProtected(t)) {
    g.strokeStyle = 'rgba(255,248,210,.75)';
    g.fillStyle = 'rgba(255,249,214,.1)';
    g.lineWidth = 2.4;
    g.setLineDash([10, 8]);
    ellipse(g, 0, -80, 84, 96);
    g.fill();
    g.stroke();
    g.setLineDash([]);
    drawStar(g, 0, -170, 4, 5, 2, 0, 'rgba(255,238,170,.85)');
  }

  /* 开火闪光 */
  if (recoil > 0.02) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = recoil * 0.85;
    const mg = g.createRadialGradient(0, -154, 2, 0, -154, 35);
    mg.addColorStop(0, 'rgba(255,255,240,.95)');
    mg.addColorStop(0.45, t.team === 'blue' ? 'rgba(150,245,255,.5)' : 'rgba(255,190,160,.5)');
    mg.addColorStop(1, 'rgba(255,220,160,0)');
    g.fillStyle = mg;
    ellipse(g, 0, -154, 35, 28);
    g.fill();
    drawStar(g, 0, -154, 4, 6 + recoil * 4, 2.2, time * 3, '#fff7d6');
    g.restore();
  }

  /* 受击白闪 */
  if (hitP > 0.01) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = hitP * 0.4;
    const hg = g.createRadialGradient(0, -105, 4, 0, -105, 70);
    hg.addColorStop(0, 'rgba(255,255,245,.9)');
    hg.addColorStop(1, 'rgba(255,240,200,0)');
    g.fillStyle = hg;
    ellipse(g, 0, -105, 70, 76);
    g.fill();
    g.restore();
  }

  /* 射程提示 */
  if (world && player && dist(player.x, player.y, t.x, t.y) < t.range + 260) {
    g.strokeStyle = t.team === 'blue' ? 'rgba(90,220,230,.14)' : 'rgba(255,140,120,.16)';
    g.lineWidth = 2;
    g.setLineDash([9, 12]);
    ellipse(g, 0, 0, t.range / 0.84, t.range * 0.9 / 0.84);
    g.stroke();
    g.setLineDash([]);
  }
  g.restore();
}

function isTowerProtected(t) {
  if (!world) return false;
  if (t.tier === 0) return false;
  const outer = world.towers[t.team].find(x => x.tier === 0);
  return outer && outer.alive;
}

function drawBaseSprite(g, b, time) {
  const atkP = b.atkAnim > 0 ? 1 - b.atkAnim / 0.32 : 0;
  const recoil = Math.sin(atkP * Math.PI);
  const hitP = b.hitT > 0 ? Math.sin((1 - b.hitT / 0.2) * Math.PI) : 0;
  g.save();
  g.translate(b.x, b.y);
  const light = b.team === 'blue' ? '#8fe3ef' : '#ffb9a8';
  const dark = b.team === 'blue' ? '#2f9fae' : '#d95845';
  const glow = b.team === 'blue' ? 'rgba(94,220,220,' : 'rgba(255,150,120,';

  g.fillStyle = 'rgba(30,80,58,.18)';
  ellipse(g, 0, 12, 78, 22);
  g.fill();

  /* 花瓣底座 */
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * TAU + 0.2;
    g.fillStyle = i % 2 === 0 ? '#fff1d4' : '#f8ddb2';
    ellipse(g, Math.cos(a) * 44, Math.sin(a) * 22 + 2, 26, 13, a);
    g.fill();
    g.strokeStyle = 'rgba(205,165,105,.25)';
    g.lineWidth = 1.4;
    g.stroke();
  }
  /* 苔藓石台 */
  const stage = g.createRadialGradient(-12, -10, 4, 0, 0, 62);
  stage.addColorStop(0, '#fffdf4');
  stage.addColorStop(0.62, '#fdf0d2');
  stage.addColorStop(1, b.team === 'blue' ? '#c8ebe2' : '#ffd9cb');
  g.fillStyle = stage;
  ellipse(g, 0, 0, 62, 29);
  g.fill();
  g.strokeStyle = 'rgba(170,135,80,.3)';
  g.lineWidth = 2.4;
  ellipse(g, 0, 0, 62, 29);
  g.stroke();
  /* 符文圈 */
  g.strokeStyle = b.team === 'blue' ? 'rgba(70,200,200,.55)' : 'rgba(255,150,120,.55)';
  g.lineWidth = 2;
  g.setLineDash([7, 6]);
  ellipse(g, 0, 0, 44, 19);
  g.stroke();
  g.setLineDash([]);
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * TAU + time * 0.1;
    drawStar(g, Math.cos(a) * 36, Math.sin(a) * 15, 4, 3.4, 1.3, 0,
      b.team === 'blue' ? 'rgba(120,235,235,.75)' : 'rgba(255,180,150,.8)');
  }
  /* 小苔藓 */
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * TAU + 0.5;
    g.fillStyle = '#9fd8ab';
    ellipse(g, Math.cos(a) * 54, Math.sin(a) * 24, 5, 2.6);
    g.fill();
  }

  /* 光环 */
  const aura = g.createRadialGradient(0, -70, 10, 0, -70, 120);
  aura.addColorStop(0, glow + '.28)');
  aura.addColorStop(1, glow + '0)');
  g.fillStyle = aura;
  ellipse(g, 0, -70, 120, 120);
  g.fill();

  /* 水晶 */
  const cy = -86 + Math.sin(time * 1.6) * 6 - recoil * 4;
  const crystal = g.createLinearGradient(-30, cy - 60, 30, cy + 55);
  crystal.addColorStop(0, '#ffffff');
  crystal.addColorStop(0.35, light);
  crystal.addColorStop(1, dark);
  g.fillStyle = crystal;
  g.beginPath();
  g.moveTo(0, cy - 58);
  g.lineTo(26, cy - 12);
  g.lineTo(15, cy + 38);
  g.lineTo(0, cy + 52);
  g.lineTo(-15, cy + 38);
  g.lineTo(-26, cy - 12);
  g.closePath();
  g.fill();
  g.strokeStyle = 'rgba(255,255,255,.65)';
  g.lineWidth = 2.2;
  g.stroke();
  /* 切面 */
  g.strokeStyle = 'rgba(255,255,255,.4)';
  g.lineWidth = 1.6;
  g.beginPath();
  g.moveTo(0, cy - 58); g.lineTo(-8, cy - 6); g.lineTo(0, cy + 52);
  g.moveTo(-8, cy - 6); g.lineTo(-26, cy - 12);
  g.moveTo(-8, cy - 6); g.lineTo(26, cy - 12);
  g.stroke();
  g.fillStyle = 'rgba(255,255,255,.75)';
  ellipse(g, -6, cy - 24, 4, 12, -0.3);
  g.fill();

  /* 环绕星星 */
  for (let i = 0; i < 4; i++) {
    const a = time * 0.9 + (i / 4) * TAU;
    drawStar(g, Math.cos(a) * 46, cy + Math.sin(a) * 22, 4, 5, 2, 0, 'rgba(255,247,200,.9)');
  }

  /* 保护罩 */
  if (isBaseProtected(b)) {
    g.strokeStyle = 'rgba(255,248,210,.75)';
    g.fillStyle = 'rgba(255,249,214,.09)';
    g.lineWidth = 2.6;
    g.setLineDash([12, 9]);
    ellipse(g, 0, -70, 96, 106);
    g.fill();
    g.stroke();
    g.setLineDash([]);
  }

  /* 两侧小旗 */
  [-70, 70].forEach((px, i) => {
    g.strokeStyle = '#a98457';
    g.lineWidth = 3;
    g.beginPath();
    g.moveTo(px, 0);
    g.lineTo(px, -64);
    g.stroke();
    g.fillStyle = i === 0 ? light : dark;
    g.beginPath();
    g.moveTo(px, -64);
    g.quadraticCurveTo(px + 14, -60 + Math.sin(time * 3 + i) * 2, px + 22, -52);
    g.quadraticCurveTo(px + 10, -46, px, -49);
    g.closePath();
    g.fill();
  });

  /* 开火 / 受击 */
  if (recoil > 0.02) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = recoil * 0.8;
    const mg = g.createRadialGradient(0, cy - 40, 2, 0, cy - 40, 42);
    mg.addColorStop(0, 'rgba(255,255,244,.9)');
    mg.addColorStop(1, 'rgba(255,235,180,0)');
    g.fillStyle = mg;
    ellipse(g, 0, cy - 40, 42, 34);
    g.fill();
    g.restore();
  }
  if (hitP > 0.01) {
    g.save();
    g.globalCompositeOperation = 'lighter';
    g.globalAlpha = hitP * 0.45;
    const hg = g.createRadialGradient(0, -90, 4, 0, -90, 78);
    hg.addColorStop(0, 'rgba(255,255,248,.9)');
    hg.addColorStop(1, 'rgba(255,238,190,0)');
    g.fillStyle = hg;
    ellipse(g, 0, -90, 78, 84);
    g.fill();
    g.restore();
  }
  g.restore();
}

function isBaseProtected(b) {
  if (!world) return false;
  if (world.suddenDeath) return false;
  return world.towers[b.team].some(t => t.alive);
}

function drawHoneySprite(g, p, time) {
  const bob = Math.sin(time * 3 + p.seed) * 4;
  g.save();
  g.translate(p.x, p.y + bob);
  g.fillStyle = 'rgba(30,80,58,.16)';
  ellipse(g, 0, 12 - bob, 24, 8);
  g.fill();
  /* 小翅膀 */
  g.fillStyle = 'rgba(255,255,255,.7)';
  ellipse(g, -25 - Math.sin(time * 22) * 4, -42, 12, 6, -0.5);
  ellipse(g, 24 + Math.sin(time * 22) * 4, -42, 12, 6, 0.5);
  g.fill();
  /* 罐子 */
  const jar = g.createLinearGradient(0, -48, 0, 8);
  jar.addColorStop(0, '#ffe08a');
  jar.addColorStop(1, '#f0a63c');
  g.fillStyle = jar;
  roundRect(g, -24, -44, 48, 46, 14);
  g.fill();
  g.strokeStyle = 'rgba(170,105,30,.35)';
  g.lineWidth = 2.4;
  g.stroke();
  g.fillStyle = '#fff3cc';
  g.beginPath();
  g.moveTo(-24, -36);
  g.quadraticCurveTo(0, -30, 24, -36);
  g.lineTo(24, -28);
  g.quadraticCurveTo(0, -20, -24, -28);
  g.closePath();
  g.fill();
  /* 盖子 */
  g.fillStyle = '#c9823a';
  roundRect(g, -15, -56, 30, 14, 7);
  g.fill();
  g.fillStyle = '#ffe9b8';
  roundRect(g, -11, -53, 22, 5, 3);
  g.fill();
  /* 光 */
  drawStar(g, 0, -22, 5, 8, 3.6, 0, 'rgba(255,255,255,.85)');
  /* 小脸 */
  fillBlobs(g, '#8a5a20', [[-8, -9, 2.2, 2.8], [8, -9, 2.2, 2.8]]);
  g.strokeStyle = '#8a5a20';
  g.lineWidth = 1.6;
  g.beginPath();
  g.arc(0, -6, 4, 0.2, Math.PI - 0.2);
  g.stroke();
  g.restore();
}

/* ============================================================
   投射物 / 特效
   ============================================================ */
/* 地面减速区：裂谷 / 水道，半透明椭圆 + 流动虚线边 + 内部小纹 */
function drawZone(g, z, time) {
  const p = clamp(z.t / z.life, 0, 1);
  const fade = p < 0.1 ? p / 0.1 : 1 - (p - 0.1) / 0.9;
  g.save();
  g.globalAlpha = clamp(fade, 0, 1) * 0.9;
  g.fillStyle = z.color;
  ellipse(g, z.x, z.y, z.r, z.r * 0.56);
  g.fill();
  g.strokeStyle = 'rgba(255,255,255,.42)';
  g.lineWidth = 2.4;
  g.setLineDash([9, 11]);
  g.lineDashOffset = -time * 16;
  ellipse(g, z.x, z.y, z.r * 0.96, z.r * 0.54);
  g.stroke();
  g.setLineDash([]);
  g.strokeStyle = 'rgba(255,255,255,.2)';
  g.lineWidth = 1.6;
  for (let i = 0; i < 5; i++) {
    const a = time * 0.5 + i * 1.27;
    const rr = z.r * (0.3 + (i % 3) * 0.2);
    g.beginPath();
    g.ellipse(z.x + Math.cos(a) * rr * 0.6, z.y + Math.sin(a) * rr * 0.34, 9 + (i % 2) * 5, 4, a * 0.4, 0, TAU);
    g.stroke();
  }
  g.restore();
}

function drawProjectile(g, p) {
  const ang = Math.atan2(p.vy, p.vx);
  const col = p.color || '#ffe6a3';
  g.save();
  g.translate(p.x, p.y);
  g.rotate(ang);

  if (p.style === 'bubble') {
    /* 水泡：半透明球 + 高光 + 外圈，撞开时很好认 */
    const r = p.size * 1.15;
    g.globalAlpha = 0.5;
    const fill = g.createRadialGradient(-r * 0.3, -r * 0.35, r * 0.15, 0, 0, r);
    fill.addColorStop(0, 'rgba(255,255,255,.85)');
    fill.addColorStop(0.55, col);
    fill.addColorStop(1, 'rgba(120,200,240,.25)');
    g.fillStyle = fill;
    ellipse(g, 0, 0, r, r);
    g.fill();
    g.globalAlpha = 0.9;
    g.strokeStyle = 'rgba(255,255,255,.75)';
    g.lineWidth = 1.8;
    ellipse(g, 0, 0, r, r);
    g.stroke();
    g.globalAlpha = 0.5;
    g.strokeStyle = col;
    g.lineWidth = 3;
    g.lineCap = 'round';
    g.beginPath();
    g.moveTo(-r * 2.6, 0);
    g.quadraticCurveTo(-r * 1.4, -3, -r * 0.9, 0);
    g.stroke();
    g.restore();
    return;
  }

  if (p.style === 'spike') {
    /* 尖刺：拉长的针形，尖端最亮 */
    const L = p.size * 3.1, W = p.size * 0.72;
    g.globalAlpha = 0.45;
    g.fillStyle = col;
    g.beginPath();
    g.moveTo(-L * 0.4, -W);
    g.lineTo(L * 1.15, 0);
    g.lineTo(-L * 0.4, W);
    g.closePath();
    g.fill();
    g.globalAlpha = 1;
    g.fillStyle = '#fff6dd';
    g.beginPath();
    g.moveTo(L * 0.1, -W * 0.42);
    g.lineTo(L * 1.25, 0);
    g.lineTo(L * 0.1, W * 0.42);
    g.closePath();
    g.fill();
    g.restore();
    return;
  }

  /* 尾迹 */
  g.globalCompositeOperation = 'lighter';
  const trail = g.createLinearGradient(-34, 0, 4, 0);
  trail.addColorStop(0, 'rgba(255,255,255,0)');
  trail.addColorStop(1, col);
  g.strokeStyle = trail;
  g.lineWidth = p.size * 1.4;
  g.lineCap = 'round';
  g.globalAlpha = 0.6;
  g.beginPath();
  g.moveTo(-30, 0);
  g.lineTo(0, 0);
  g.stroke();
  g.globalAlpha = 1;
  g.fillStyle = col;
  ellipse(g, 0, 0, p.size * 1.35, p.size * 0.9);
  g.fill();
  g.fillStyle = '#fff';
  ellipse(g, 0, 0, p.size * 0.6, p.size * 0.6);
  g.fill();
  if (p.style === 'star' || p.style === 'dart') {
    g.rotate(-ang);
    drawStar(g, 0, 0, 4, p.size * 2.1, p.size * 0.8, 0, col);
  }
  g.restore();
}

function drawEffect(g, e, worldTime) {
  const p = clamp(e.t / e.life, 0, 1);
  const fade = 1 - p;
  switch (e.type) {
    case 'slash': {
      g.save();
      g.translate(e.x, e.y);
      g.rotate(e.angle);
      g.globalAlpha = fade;
      g.strokeStyle = e.color || 'rgba(255,255,255,.9)';
      g.lineWidth = e.width || 7;
      g.lineCap = 'round';
      g.beginPath();
      g.arc(0, 0, e.r || 42, -0.9 + p * 0.7, 0.9 + p * 0.7);
      g.stroke();
      g.globalAlpha = fade * 0.35;
      g.lineWidth = 14;
      g.stroke();
      g.restore();
      break;
    }
    case 'ring': {
      const r = lerp(e.r0 || 10, e.r1 || 120, 1 - Math.pow(1 - p, 2));
      g.save();
      g.globalAlpha = fade * (e.alpha == null ? 1 : e.alpha);
      g.strokeStyle = e.color || '#ffe6a3';
      g.lineWidth = (e.width || 6) * (1 - p * 0.5);
      ellipse(g, e.x, e.y, r, r * (e.squash || 1));
      g.stroke();
      g.restore();
      break;
    }
    case 'burst': {
      g.save();
      g.translate(e.x, e.y);
      g.globalCompositeOperation = 'lighter';
      const n = e.count || 8;
      const rr = (e.r || 60) * (1 - Math.pow(1 - p, 2));
      for (let i = 0; i < n; i++) {
        const a = (i / n) * TAU + (e.seed || 0);
        const spread = rr * (0.75 + (i % 3) * 0.12);
        g.globalAlpha = fade;
        g.fillStyle = e.color || '#ffe6a3';
        if (i % 3 === 0) {
          drawStar(g, Math.cos(a) * spread, Math.sin(a) * spread, 4, 5.5, 2, 0, e.color || '#ffe6a3');
        } else {
          ellipse(g, Math.cos(a) * spread, Math.sin(a) * spread, 4.2 * (1 - p * 0.5), 3 * (1 - p * 0.5));
          g.fill();
        }
      }
      g.restore();
      break;
    }
    case 'text': {
      g.save();
      const rise = p * 42;
      const scale = p < 0.15 ? lerp(1.6, 1, p / 0.15) : 1;
      g.globalAlpha = p > 0.72 ? (1 - p) / 0.28 : 1;
      g.translate(e.x + (e.dx || 0) * p, e.y - rise);
      g.scale(scale, scale);
      g.font = `900 ${e.size || 21}px "HarmonyOS Sans SC","Microsoft YaHei",sans-serif`;
      g.textAlign = 'center';
      g.textBaseline = 'middle';
      g.lineWidth = 4;
      g.strokeStyle = 'rgba(24,58,46,.75)';
      g.strokeText(e.text, 0, 0);
      g.fillStyle = e.color || '#fff7d6';
      g.fillText(e.text, 0, 0);
      g.restore();
      break;
    }
    case 'warn': {
      g.save();
      g.globalAlpha = 0.35 + Math.sin(worldTime * 12) * 0.15;
      g.strokeStyle = e.color || '#ffb15c';
      g.fillStyle = 'rgba(255,170,90,.16)';
      g.lineWidth = 3;
      g.setLineDash([8, 7]);
      ellipse(g, e.x, e.y, e.r, e.r * 0.8);
      g.fill();
      g.stroke();
      g.setLineDash([]);
      g.globalAlpha = 0.55;
      g.strokeStyle = e.color || '#ffb15c';
      g.beginPath();
      g.arc(e.x, e.y, e.r * (0.35 + Math.sin(worldTime * 6) * 0.1), 0, TAU);
      g.stroke();
      g.restore();
      break;
    }
    case 'meteor': {
      g.save();
      g.globalCompositeOperation = 'lighter';
      const fall = 1 - Math.pow(1 - p, 3);
      const sx = e.x - 90 * (1 - fall), sy = e.y - 300 * (1 - fall);
      g.strokeStyle = 'rgba(255,174,92,.72)';
      g.lineWidth = 10 * (1 - p * 0.4);
      g.lineCap = 'round';
      g.beginPath();
      g.moveTo(sx - 84, sy - 190);
      g.lineTo(sx, sy);
      g.stroke();
      drawStar(g, sx, sy, 6, 19, 8, worldTime * 3, '#ffd27e');
      g.restore();
      break;
    }
    case 'heal': {
      g.save();
      g.globalAlpha = fade;
      g.strokeStyle = e.color || '#9ef2b8';
      g.fillStyle = e.color || '#9ef2b8';
      g.lineWidth = 3.4;
      const rise = p * 46;
      for (let i = 0; i < (e.count || 5); i++) {
        const a = (i / (e.count || 5)) * TAU + (e.seed || 0);
        const x = e.x + Math.cos(a) * (e.r || 40) * (0.4 + p * 0.6);
        const y = e.y - 20 - rise + Math.sin(a) * 10;
        g.globalAlpha = fade * 0.9;
        g.beginPath();
        g.moveTo(x - 5, y);
        g.lineTo(x + 5, y);
        g.moveTo(x, y - 5);
        g.lineTo(x, y + 5);
        g.stroke();
      }
      g.restore();
      break;
    }
    case 'beam': {
      g.save();
      g.globalCompositeOperation = 'lighter';
      const w = (e.width || 26) * (0.6 + (1 - p) * 0.7);
      const grad = g.createLinearGradient(e.x, e.y - 260, e.x, e.y);
      grad.addColorStop(0, 'rgba(255,255,255,0)');
      grad.addColorStop(0.7, e.color || 'rgba(255,236,160,.8)');
      grad.addColorStop(1, 'rgba(255,255,255,0)');
      g.globalAlpha = fade;
      g.fillStyle = grad;
      g.fillRect(e.x - w / 2, e.y - 260, w, 270);
      g.restore();
      break;
    }
    case 'dashTrail': {
      g.save();
      g.globalAlpha = fade * 0.7;
      g.strokeStyle = e.color || 'rgba(255,236,190,.9)';
      g.lineWidth = 10 * fade;
      g.lineCap = 'round';
      g.beginPath();
      g.moveTo(e.x1, e.y1);
      g.lineTo(e.x2, e.y2);
      g.stroke();
      g.restore();
      break;
    }
    case 'spark': {
      g.save();
      g.globalCompositeOperation = 'lighter';
      g.globalAlpha = fade;
      g.fillStyle = e.color || '#fff3b8';
      ellipse(g, e.x + Math.sin(worldTime * 4 + (e.seed || 0)) * 8, e.y - p * 20, 3.2 * fade, 3.2 * fade);
      g.fill();
      g.restore();
      break;
    }
    case 'dust': {
      g.save();
      const rr = (e.size || 6) * (0.55 + p * 1.5);
      g.globalAlpha = fade * 0.55;
      g.fillStyle = e.color || 'rgba(232,240,214,.6)';
      ellipse(g, e.x - p * 5, e.y - p * 5, rr, rr * 0.48);
      g.fill();
      g.globalAlpha = fade * 0.3;
      ellipse(g, e.x + p * 3, e.y - p * 2, rr * 0.6, rr * 0.3);
      g.fill();
      g.restore();
      break;
    }
    case 'hitSpark': {
      const big = e.big ? 1.35 : 1;
      g.save();
      g.translate(e.x, e.y);
      g.globalCompositeOperation = 'lighter';
      g.globalAlpha = fade;
      const rg = g.createRadialGradient(0, 0, 1, 0, 0, (12 + 10 * (1 - p)) * big);
      rg.addColorStop(0, 'rgba(255,255,245,.95)');
      rg.addColorStop(0.4, 'rgba(255,228,160,.55)');
      rg.addColorStop(1, 'rgba(255,222,140,0)');
      g.fillStyle = rg;
      ellipse(g, 0, 0, (12 + 10 * (1 - p)) * big, (12 + 10 * (1 - p)) * big);
      g.fill();
      g.strokeStyle = '#fff8d2';
      g.lineWidth = 2.6 * fade * big;
      g.lineCap = 'round';
      for (let i = 0; i < 6; i++) {
        const a = (e.seed || 0) + i * TAU / 6 + p * (e.dir || 1) * 0.25;
        const r0 = 4 + p * 8 * big, r1 = (10 + p * 26) * big;
        g.beginPath();
        g.moveTo(Math.cos(a) * r0, Math.sin(a) * r0 * 0.7);
        g.lineTo(Math.cos(a) * r1, Math.sin(a) * r1 * 0.7);
        g.stroke();
      }
      drawStar(g, 0, 0, 4 + (e.big ? 1 : 0), (7 + 5 * fade) * big, (3 + 2 * fade) * big, worldTime * 6, e.color || '#fff3c4');
      g.restore();
      break;
    }
    case 'petalFall': {
      g.save();
      g.globalAlpha = fade;
      for (let i = 0; i < 7; i++) {
        const a = (e.seed || 0) + i * 2.4;
        const x = e.x + Math.sin(a + worldTime * 1.7) * (16 + p * 40) + Math.cos(a) * 10;
        const y = e.y + p * (12 + i * 8) + Math.sin(a * 1.7) * 10;
        g.save();
        g.translate(x, y);
        g.rotate(a + p * 4);
        g.fillStyle = e.color || '#bdf6ee';
        ellipse(g, 0, 0, 3.6, 2.1);
        g.fill();
        g.restore();
      }
      g.restore();
      break;
    }
  }
}

function drawShadow(g, u) {
  g.fillStyle = 'rgba(30,80,58,.18)';
  ellipse(g, u.x, u.y + 2, u.radius * 1.1, u.radius * 0.36);
  g.fill();
}

/* ============================================================
   血条 / 名字 / 小地图 / 摇杆 / 氛围
   ============================================================ */
function drawUnitHud(g, u, time) {
  if (!u.alive) return;
  const isHero = u.kind === 'hero';
  if (isHero) {
    let stack = 0;
    if (world) {
      for (const o of world.heroes) {
        if (o === u || !o.alive) continue;
        if (Math.abs(o.x - u.x) > 78 || Math.abs(o.y - u.y) > 54) continue;
        if (u.isPlayer) continue;
        if (o.isPlayer || o.uid < u.uid) stack++;
      }
    }
    const w = 70, y = u.y - 118 - Math.min(2, stack) * 20;
    g.save();
    const tc = teamColor(u.team);
    /* 名字 */
    g.font = '800 13px "HarmonyOS Sans SC","Microsoft YaHei",sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'bottom';
    g.lineWidth = 4;
    g.strokeStyle = 'rgba(20,55,44,.7)';
    const label = HERO_DEFS[u.heroId].name + (u.isPlayer ? ' · 你' : '');
    g.strokeText(label, u.x, y - 4);
    g.fillStyle = u.isPlayer ? '#ffe9a8' : (u.team === 'blue' ? '#d7fffa' : '#ffe0d8');
    g.fillText(label, u.x, y - 4);
    /* 血条 */
    roundRect(g, u.x - w / 2, y, w, 8, 4);
    g.fillStyle = 'rgba(12,38,30,.7)';
    g.fill();
    roundRect(g, u.x - w / 2 + 1, y + 1, (w - 2) * clamp(u.hp / u.maxHp, 0, 1), 6, 3);
    g.fillStyle = u.team === 'blue' ? '#5ee3b0' : '#ff8b78';
    g.fill();
    if (u.shield > 0) {
      roundRect(g, u.x - w / 2 + 1, y + 1, (w - 2) * clamp(u.shield / u.maxHp, 0, 1), 3, 2);
      g.fillStyle = 'rgba(160,235,255,.85)';
      g.fill();
    }
    /* 队伍色小点 */
    g.fillStyle = tc;
    ellipse(g, u.x - w / 2 - 4, y + 4, 2.4, 2.4);
    g.fill();
    g.restore();
  } else if (u.kind === 'minion') {
    if (u.hp >= u.maxHp) return;
    const w = u.big ? 38 : 28, y = u.y - (u.big ? 64 : 46);
    roundRect(g, u.x - w / 2, y, w, 4.5, 2);
    g.fillStyle = 'rgba(12,38,30,.55)';
    g.fill();
    roundRect(g, u.x - w / 2, y, w * clamp(u.hp / u.maxHp, 0, 1), 4.5, 2);
    g.fillStyle = u.team === 'blue' ? '#62e0c4' : '#ff9b86';
    g.fill();
  } else if (u.kind === 'tower') {
    const w = 120, y = u.y - 186;
    g.save();
    drawHealthPlate(g, u.x, y, w, u.hp / u.maxHp, u.team, '蘑菇塔', u.shieldBroken > 0);
    if (isTowerProtected(u)) {
      g.font = '800 10px "HarmonyOS Sans SC","Microsoft YaHei",sans-serif';
      g.textAlign = 'center';
      g.fillStyle = 'rgba(255,244,200,.9)';
      g.fillText('保护中', u.x, y - 7);
    }
    g.restore();
  } else if (u.kind === 'base') {
    const w = 146, y = u.y - 208;
    g.save();
    drawHealthPlate(g, u.x, y, w, u.hp / u.maxHp, u.team, '水晶', false);
    if (isBaseProtected(u)) {
      g.font = '800 10px "HarmonyOS Sans SC","Microsoft YaHei",sans-serif';
      g.textAlign = 'center';
      g.fillStyle = 'rgba(255,244,200,.9)';
      g.fillText('保护中', u.x, y - 7);
    }
    g.restore();
  } else if (u.kind === 'pickup') {
    g.save();
    g.font = '800 11px "HarmonyOS Sans SC","Microsoft YaHei",sans-serif';
    g.textAlign = 'center';
    g.lineWidth = 3;
    g.strokeStyle = 'rgba(20,55,44,.6)';
    g.strokeText('蜂蜜', u.x, u.y - 66);
    g.fillStyle = '#ffe6a0';
    g.fillText('蜂蜜', u.x, u.y - 66);
    g.restore();
  }
}

function drawHealthPlate(g, x, y, w, ratio, team, label, shieldBroken) {
  roundRect(g, x - w / 2 - 2, y - 2, w + 4, 14, 7);
  g.fillStyle = 'rgba(10,34,27,.72)';
  g.fill();
  roundRect(g, x - w / 2, y, w * clamp(ratio, 0, 1), 10, 5);
  g.fillStyle = team === 'blue' ? 'linear' : 'linear';
  const grd = g.createLinearGradient(x - w / 2, 0, x + w / 2, 0);
  if (team === 'blue') { grd.addColorStop(0, '#57d8e0'); grd.addColorStop(1, '#35a7b3'); }
  else { grd.addColorStop(0, '#ff9c85'); grd.addColorStop(1, '#e36350'); }
  g.fillStyle = grd;
  g.fill();
  g.font = '800 10px "HarmonyOS Sans SC","Microsoft YaHei",sans-serif';
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  g.fillStyle = 'rgba(255,251,235,.95)';
  g.fillText(label, x, y + 5.5);
}

function drawMinimap(g, w, h, world, time) {
  const W = 220, H = 120, scale = Math.min(W / WORLD.w, H / WORLD.h);
  const ox = (W - WORLD.w * scale) / 2 - 1.5, oy = (H - WORLD.h * scale) / 2 + 1;
  g.clearRect(0, 0, W, H);
  roundRect(g, 0, 0, W, H, 10);
  g.fillStyle = '#1d4c3f';
  g.fill();
  /* 草地 */
  g.fillStyle = '#2b6353';
  roundRect(g, 0, 0, W, H, 10);
  g.fill();
  /* 河 */
  g.strokeStyle = 'rgba(120,220,230,.4)';
  g.lineWidth = 7;
  g.beginPath();
  g.moveTo(ox + 1500 * scale, oy);
  g.lineTo(ox + 1500 * scale, oy + H);
  g.stroke();
  /* 主路 */
  g.strokeStyle = 'rgba(250,230,185,.55)';
  g.lineWidth = 5;
  g.beginPath();
  LANE.forEach((p, i) => {
    const x = ox + p.x * scale, y = oy + p.y * scale;
    if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
  });
  g.stroke();
  /* 塔 */
  ['blue', 'red'].forEach(team => {
    world.towers[team].forEach(t => {
      if (!t.alive) return;
      g.fillStyle = team === 'blue' ? '#59dbe5' : '#ff8b76';
      g.beginPath();
      g.arc(ox + t.x * scale, oy + t.y * scale, 3.4, 0, TAU);
      g.fill();
    });
    const b = world.bases[team];
    g.fillStyle = b.alive ? (team === 'blue' ? '#8ff0f4' : '#ffb6a6') : 'rgba(120,120,120,.6)';
    drawStar(g, ox + b.x * scale, oy + b.y * scale, 4, 5, 2, 0, g.fillStyle);
  });
  /* 小兵 */
  world.units.forEach(u => {
    if (u.kind !== 'minion' || !u.alive) return;
    g.fillStyle = u.team === 'blue' ? 'rgba(120,235,240,.8)' : 'rgba(255,160,140,.8)';
    ellipse(g, ox + u.x * scale, oy + u.y * scale, 1.4, 1.4);
    g.fill();
  });
  /* 英雄 */
  world.heroes.forEach(hero => {
    if (!hero.alive) return;
    const x = ox + hero.x * scale, y = oy + hero.y * scale;
    if (hero.isPlayer) {
      g.fillStyle = '#ffe07a';
      g.beginPath();
      g.arc(x, y, 4.2 + Math.sin(time * 4) * 0.6, 0, TAU);
      g.fill();
      g.strokeStyle = '#fff8dc';
      g.lineWidth = 1.4;
      g.stroke();
    } else {
      g.fillStyle = hero.team === 'blue' ? '#7de8ef' : '#ffa898';
      g.beginPath();
      g.arc(x, y, 2.8, 0, TAU);
      g.fill();
    }
  });
  /* 边框 */
  g.strokeStyle = 'rgba(255,255,255,.18)';
  g.lineWidth = 1;
  roundRect(g, 1, 1, W - 2, H - 2, 10);
  g.stroke();
}

function drawJoystick(g, joy, cw, ch) {
  if (!joy) return;
  const base = joy.active ? { x: joy.bx, y: joy.by } : { x: 100 + 20, y: ch - 118 };
  const radius = joy.active ? 66 : 60;
  const knob = 27;
  const dx = joy.active ? joy.dx : 0;
  const dy = joy.active ? joy.dy : 0;
  const alpha = joy.active ? 0.95 : 0.58;
  g.save();
  g.globalAlpha = alpha;
  /* 外圈光晕 */
  const glow = g.createRadialGradient(base.x, base.y, radius * 0.4, base.x, base.y, radius * 1.5);
  glow.addColorStop(0, 'rgba(255,248,220,.12)');
  glow.addColorStop(1, 'rgba(255,248,220,0)');
  g.fillStyle = glow;
  ellipse(g, base.x, base.y, radius * 1.6, radius * 1.6);
  g.fill();
  g.strokeStyle = 'rgba(255,249,228,.65)';
  g.lineWidth = 2.4;
  ellipse(g, base.x, base.y, radius, radius);
  g.stroke();
  g.strokeStyle = 'rgba(255,249,228,.28)';
  g.lineWidth = 1.4;
  ellipse(g, base.x, base.y, radius * 0.72, radius * 0.72);
  g.stroke();
  /* 方向小点 */
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * TAU;
    g.fillStyle = 'rgba(255,249,228,.4)';
    ellipse(g, base.x + Math.cos(a) * radius * 0.82, base.y + Math.sin(a) * radius * 0.82, 2.4, 2.4);
    g.fill();
  }
  /* 摇杆头 */
  const kx = base.x + dx * radius * 0.62, ky = base.y + dy * radius * 0.62;
  const knobGrad = g.createRadialGradient(kx - knob * 0.3, ky - knob * 0.4, 2, kx, ky, knob);
  knobGrad.addColorStop(0, 'rgba(255,252,240,.98)');
  knobGrad.addColorStop(1, 'rgba(255,224,160,.9)');
  g.fillStyle = knobGrad;
  ellipse(g, kx, ky, knob, knob);
  g.fill();
  g.strokeStyle = 'rgba(160,110,60,.3)';
  g.lineWidth = 2;
  g.stroke();
  drawStar(g, kx, ky, 4, 9, 3.6, 0, 'rgba(190,130,60,.55)');
  g.restore();
}

/* 飘落的花瓣 / 萤光（世界坐标） */
function drawAmbient(g, petals, time) {
  petals.forEach(p => {
    const x = p.x + Math.sin(time * p.sway + p.phase) * 22;
    const y = ((p.y + time * p.speed) % (WORLD.h + 120)) - 60;
    if (!pointInView(x, y, 80)) return;
    g.save();
    g.globalAlpha = p.alpha * (0.7 + Math.sin(time * 2 + p.phase) * 0.3);
    g.translate(x, y);
    g.rotate(time * p.spin + p.phase);
    g.fillStyle = p.color;
    ellipse(g, 0, 0, p.size, p.size * 0.55);
    g.fill();
    g.restore();
  });
  /* 水晶周围的光点 */
  if (world) {
    ['blue', 'red'].forEach((t, idx) => {
      const b = world.bases[t];
      for (let i = 0; i < 5; i++) {
        const a = time * 0.7 + i * 1.3 + idx * 2;
        const x = b.x + Math.cos(a) * (70 + Math.sin(time + i) * 12);
        const y = b.y - 80 + Math.sin(a * 1.4) * 36;
        if (!pointInView(x, y, 80)) continue;
        g.save();
        g.globalCompositeOperation = 'lighter';
        g.globalAlpha = 0.35 + Math.sin(time * 3 + i) * 0.25;
        g.fillStyle = t === 'blue' ? '#bff9ff' : '#ffd0bd';
        ellipse(g, x, y, 2.6, 2.6);
        g.fill();
        g.restore();
      }
    });
    /* 林间漂浮光尘 */
    for (let i = 0; i < 14; i++) {
      const a = i * 2.39 + world.time * 0.12;
      const x = 1500 + Math.sin(a * 0.7) * 1280 + Math.sin(time * 0.6 + i) * 30;
      const y = 560 + Math.cos(a * 0.5) * 480 + Math.cos(time * 0.5 + i * 1.7) * 24;
      if (!pointInView(x, y, 60)) continue;
      g.save();
      g.globalCompositeOperation = 'lighter';
      g.globalAlpha = 0.2 + (Math.sin(time * 1.6 + i) * 0.5 + 0.5) * 0.45;
      const rg = g.createRadialGradient(x, y, 0.5, x, y, 7);
      rg.addColorStop(0, 'rgba(255,252,208,.95)');
      rg.addColorStop(1, 'rgba(255,240,160,0)');
      g.fillStyle = rg;
      ellipse(g, x, y, 7, 7);
      g.fill();
      g.restore();
    }
  }
}

/* 蝴蝶 */
function drawButterflies(g, time) {
  const spots = [
    { x: 900, y: 760, c: '#ffe6a8', s: 1.0 },
    { x: 1640, y: 1230, c: '#ffc9dd', s: 0.9 },
    { x: 2130, y: 760, c: '#cfe5ff', s: 0.85 },
    { x: 720, y: 1330, c: '#ffe6a8', s: 0.8 },
    { x: 2380, y: 1180, c: '#ffd9ea', s: 0.95 }
  ];
  spots.forEach((b, i) => {
    if (!pointInView(b.x, b.y, 200)) return;
    const x = b.x + Math.sin(time * 0.5 + i * 1.7) * 90;
    const y = b.y + Math.cos(time * 0.7 + i * 2.1) * 46;
    const flap = Math.abs(Math.sin(time * 12 + i));
    g.save();
    g.translate(x, y);
    g.globalAlpha = 0.8;
    fillBlobs(g, b.c, [
      [-4, 0, 5 * b.s, 8 * b.s * (0.35 + flap * 0.65), -0.5],
      [4, 0, 5 * b.s, 8 * b.s * (0.35 + flap * 0.65), 0.5]
    ]);
    g.fillStyle = 'rgba(80,70,60,.7)';
    ellipse(g, 0, 0, 1.4, 4);
    g.fill();
    g.restore();
  });
}

/* RenderView 由 game.js 更新，用于裁剪 */
let RenderView = null;
