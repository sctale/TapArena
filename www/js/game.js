'use strict';
/* ============================================================
   萌兽峡谷 · 游戏逻辑与交互
   ============================================================ */

const $ = sel => document.querySelector(sel);
const $$ = sel => Array.from(document.querySelectorAll(sel));

const App = {
  screen: 'home',
  difficulty: 'easy',
  hero: 'tiger',
  sound: true,
  paused: false,
  resultShown: false,
  battleId: 0,
  lastLevel: 1,
  tipHidden: false,
  objectiveHidden: false
};

let world = null;
let player = null;
let renderCtxRef = null;
let bgCanvas = null;
/* 供 Phaser 特效层做世界→屏幕换算：每帧由 renderWorld 刷新 */
const FxView = { w: 0, h: 0, cx: 0, cy: 0, scale: 1, sx: 0, sy: 0 };
window.__FX_VIEW = () => FxView;
function fxHit(x, y, opt) {
  return typeof StageFX !== 'undefined' && StageFX.ready && StageFX.hit(x, y, opt);
}
function fxDust(x, y, color) {
  return typeof StageFX !== 'undefined' && StageFX.ready && StageFX.dust(x, y, color);
}
function fxSpark(x, y, color, count) {
  return typeof StageFX !== 'undefined' && StageFX.ready && StageFX.spark(x, y, color, count);
}
let minimapCtx = null;
let battleCanvas = null;
let ctx = null;
let PIXEL_RATIO = 1;
let lastFrame = performance.now();

const Cam = { x: BASE_POS.blue.x, y: BASE_POS.blue.y, scale: 1 };
const joy = { active: false, id: null, bx: 0, by: 0, dx: 0, dy: 0 };
const keys = new Set();

/* ---------------- DOM 缓存 ---------------- */
const ui = {};
function cacheUI() {
  [
    'screen-home', 'screen-select', 'screen-battle', 'screen-result',
    'hudAvatar', 'hudLvl', 'hudHpFill', 'hudHpText', 'hudXpFill',
    'scoreBlue', 'scoreRed', 'matchClock', 'objective', 'killfeed',
    'joystickHint', 'battleTip', 'countdown', 'levelupBanner', 'battleToast',
    'pauseOverlay', 'pauseAvatar', 'minimap', 'ultLock',
    'btnStart', 'btnHelpHome', 'btnSoundHome', 'btnBackHome', 'btnGo',
    'btnPause', 'btnResume', 'btnRestart', 'btnQuit', 'btnHelpPause', 'btnSoundPause',
    'btnAgain', 'btnChangeHero', 'btnResultHome', 'helpModal',
    'resultBadge', 'resultTitle', 'resultSub', 'resultStars', 'resultAvatar',
    'resultHeroName', 'resultHeroRole', 'rsTime', 'rsKills', 'rsDeaths', 'rsTowers',
    'resultConfetti', 'difficultyPick', 'selectDiffBadge', 'heroCards',
    'detailRole', 'detailDiff', 'detailName', 'detailTitle', 'detailTagline',
    'detailSkills', 'detailHp', 'detailAtk', 'detailRange',
    'homePetals', 'rotateHint'
  ].forEach(id => { ui[id] = document.getElementById(id); });
  ui.skillButtons = $$('.skill-btn');
  ui.screens = { home: ui['screen-home'], select: ui['screen-select'], battle: ui['screen-battle'], result: ui['screen-result'] };
}

/* ============================================================
   世界创建
   ============================================================ */
function shuffle(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function makeHero(heroId, team, isPlayer, difficulty) {
  const d = HERO_DEFS[heroId];
  let dmgScale = 1;
  if (isPlayer) dmgScale = difficulty === 'easy' ? 1.12 : 1.02;
  else if (team === 'red') dmgScale = difficulty === 'easy' ? 0.9 : 1.08;
  return {
    uid: 'h' + Math.random().toString(36).slice(2, 9),
    kind: 'hero', heroId, team, isPlayer: !!isPlayer,
    x: 0, y: 0, radius: d.radius,
    hp: d.hp, maxHp: d.hp, level: 1, xp: 0,
    damage: d.damage, range: d.range, atkInterval: d.atkInterval,
    atkTimer: rand(0.2, 0.8), speed: d.speed,
    facing: team === 'blue' ? 1 : -1, walkT: 0,
    moveDir: { x: 0, y: 0 }, lastDir: { x: team === 'blue' ? 1 : -1, y: 0 },
    shield: 0, shieldT: 0, stunT: 0, slowT: 0, hasteT: 0, invulnT: 0,
    buffT: 0, thornT: 0, dmgScale,
    cds: [0, 0, 0], alive: true, respawnT: 0,
    kills: 0, deaths: 0, towers: 0,
    atkAnim: 0, hurtT: 0, spinT: 0, castAnim: 0,
    castId: -1, atkKind: 0, hitDir: 1, deathT: 0, stepT: 0,
    seed: rand(0, 10),
    ai: {
      retreat: false, think: rand(0.1, 0.5), skillTimer: rand(0.8, 1.6),
      wp: team === 'blue' ? 1 : LANE.length - 2,
      laneOff: rand(-34, 34), strafe: rand(0, TAU), target: null
    }
  };
}

function heroSpawnPos(team, i) {
  const base = BASE_POS[team];
  const dir = team === 'blue' ? 1 : -1;
  const offs = [{ dx: 132, dy: 0 }, { dx: 86, dy: -64 }, { dx: 86, dy: 66 }];
  return { x: base.x + dir * offs[i].dx, y: base.y + offs[i].dy };
}

function placeHeroAtBase(h, i) {
  const p = heroSpawnPos(h.team, i);
  h.x = p.x; h.y = p.y;
}

function createWorld(heroId, difficulty, autoPlayer) {
  const w = {
    time: 0, countdown: 3.4, started: false, over: false, winner: null,
    overTimer: 0, headless: false, autoPlayer: !!autoPlayer, difficulty,
    units: [], heroes: [], projectiles: [], effects: [], timers: [], pickups: [],
    hitstop: 0, zoomPunch: 0, zones: [],
    towers: { blue: [], red: [] }, bases: {},
    kills: { blue: 0, red: 0 }, towerKills: { blue: 0, red: 0 },
    superMinions: { blue: 0, red: 0 },
    waveTimer: 4, wave: 0, shake: 0, shieldToastT: 0, suddenDeath: false,
    shownCount: null, petals: [], hudAcc: 0, baseOpened: { blue: false, red: false }
  };

  ['blue', 'red'].forEach(team => {
    TOWER_POS[team].forEach(spec => {
      const t = {
        uid: 't' + Math.random().toString(36).slice(2, 9),
        kind: 'tower', team, x: spec.x, y: spec.y, radius: 58, tier: spec.tier,
        hp: 2600, maxHp: 2600, range: 305, dmg: 88, atkInterval: 1.2,
        atkTimer: rand(0.4, 1.0), alive: true, seed: rand(0, 9),
        atkAnim: 0, hitT: 0
      };
      w.units.push(t);
      w.towers[team].push(t);
    });
    const bp = BASE_POS[team];
    const b = {
      uid: 'b' + Math.random().toString(36).slice(2, 9),
      kind: 'base', team, x: bp.x, y: bp.y, radius: 66,
      hp: 3600, maxHp: 3600, range: 350, dmg: 120, atkInterval: 1.9,
      atkTimer: 1.4, alive: true,
      atkAnim: 0, hitT: 0
    };
    w.units.push(b);
    w.bases[team] = b;
  });

  const others = shuffle(HERO_ORDER.filter(id => id !== heroId));
  const blueIds = [heroId, others[0], others[1]];
  /* 剩下 3 位自动归敌方：6 位英雄每局都会登场 */
  const redIds = shuffle(others.slice(2));

  blueIds.forEach((id, i) => {
    const h = makeHero(id, 'blue', i === 0, difficulty);
    placeHeroAtBase(h, i);
    w.heroes.push(h); w.units.push(h);
  });
  redIds.forEach((id, i) => {
    const h = makeHero(id, 'red', false, difficulty);
    placeHeroAtBase(h, i);
    h.facing = -1;
    w.heroes.push(h); w.units.push(h);
  });

  HONEY_SPOTS.forEach(spot => {
    w.pickups.push({
      kind: 'pickup', x: spot.x, y: spot.y, radius: 34,
      alive: true, respawnT: 0, seed: rand(0, 9)
    });
  });

  const petalColors = ['#fff6e6', '#ffe2ec', '#fff0bf', '#d9f4e4', '#ffe7d1'];
  for (let i = 0; i < 44; i++) {
    w.petals.push({
      x: rand(0, WORLD.w), y: rand(0, WORLD.h),
      speed: rand(7, 22), sway: rand(0.5, 1.6), phase: rand(0, TAU),
      spin: rand(-2.5, 2.5), size: rand(3, 6.5), alpha: rand(0.22, 0.55),
      color: pickOne(petalColors)
    });
  }
  return w;
}

/* ============================================================
   战斗更新
   ============================================================ */
function updateWorld(dt) {
  if (!world) return;
  if (world.shieldToastT > 0) world.shieldToastT -= dt;

  if (world.over) {
    world.overTimer -= dt;
    updateEffects(dt);
    updateCamera(dt);
    world.shake = Math.max(0, world.shake - dt * 30);
    if (world.overTimer <= 0 && !world.headless && !App.resultShown) showResult();
    return;
  }

  if (world.countdown > 0) {
    world.countdown -= dt;
    if (world.countdown > 0) {
      const n = Math.ceil(world.countdown);
      if (n !== world.shownCount) {
        world.shownCount = n;
        showCountdown(String(n));
        Sound.play('count');
      }
    } else {
      world.started = true;
      showCountdown('开始！');
      Sound.play('go');
    }
    updateCamera(dt, false);
    return;
  }

  /* 顿帧：命中瞬间把整个世界的 dt 压到 18%，视觉上是"打到了"的一瞬 */
  if (world.hitstop > 0) {
    world.hitstop = Math.max(0, world.hitstop - dt);
    dt *= 0.18;
  }
  if (world.zoomPunch > 0) world.zoomPunch = Math.max(0, world.zoomPunch - dt * 4.5);
  world.time += dt;
  if (world.shake > 0) world.shake = Math.max(0, world.shake - dt * 26);

  /* 8 分钟终极对决：水晶护罩全部消失 */
  if (world.time > 480 && !world.suddenDeath) {
    world.suddenDeath = true;
    world.shake = Math.max(world.shake, 10);
    if (!world.headless) {
      showToast('终极对决！水晶护罩消失了，双方水晶都可以直接攻击！', 3600);
      addKillFeed('终极对决', 'blue', '水晶护罩消失', 'red');
    }
    [world.bases.blue, world.bases.red].forEach(b => {
      if (!b.alive) return;
      addEffect({ type: 'ring', x: b.x, y: b.y - 70, r0: 30, r1: 240, color: '#ffe6a0', life: 1.2, t: 0, width: 9 });
      addEffect({ type: 'burst', x: b.x, y: b.y - 70, r: 130, count: 16, color: '#ffe6a0', life: 1, t: 0, seed: rand(0, TAU) });
    });
    Sound.play('ult');
  }

  /* 兵线 */
  world.waveTimer -= dt;
  if (world.waveTimer <= 0) {
    spawnWave(world);
    world.waveTimer = 16;
  }

  /* 英雄 */
  for (const h of world.heroes) updateHero(h, dt);
  /* 小兵 */
  for (const u of world.units) if (u.kind === 'minion' && u.alive) updateMinion(u, dt);
  /* 塔与水晶 */
  for (const u of world.units) if (u.alive && (u.kind === 'tower' || u.kind === 'base')) updateStructure(u, dt);

  updateZones(dt);
  updateProjectiles(dt);
  updatePickups(dt);
  updateTimers(dt);
  updateEffects(dt);
  separateUnits();

  /* 清理小兵 */
  if (world.units.some(u => u.kind === 'minion' && !u.alive)) {
    world.units = world.units.filter(u => u.kind !== 'minion' || u.alive);
  }

  updateCamera(dt, false);

  /* HUD */
  if (!world.headless) {
    updateSkillHUD();
    world.hudAcc += dt;
    if (world.hudAcc > 0.08) {
      world.hudAcc = 0;
      updateHUD();
    }
  }
}

/* ---------------- 小兵 ---------------- */
function spawnWave(w) {
  w.wave++;
  const tScale = 1 + w.time / 420;
  for (const team of ['blue', 'red']) {
    const dir = team === 'blue' ? 1 : -1;
    const count = 4 + (w.wave % 3 === 0 ? 1 : 0);
    for (let i = 0; i < count; i++) {
      const big = i === count - 1 && w.wave % 3 === 0;
      makeMinion(w, team, big, tScale, i);
    }
    for (let s = 0; s < w.superMinions[team]; s++) {
      makeMinion(w, team, true, tScale, 0, true);
    }
  }
}

function makeMinion(w, team, big, tScale, i, isSuper) {
  const base = BASE_POS[team];
  const dir = team === 'blue' ? 1 : -1;
  const hp = (big ? 620 : 250) * tScale * (isSuper ? 2.1 : 1);
  const dmg = (big ? 44 : 21) * tScale * (isSuper ? 1.6 : 1);
  const m = {
    uid: 'm' + Math.random().toString(36).slice(2, 9),
    kind: 'minion', team, big: big || isSuper, super: !!isSuper,
    x: base.x + dir * rand(58, 120), y: base.y + rand(-90, 90),
    radius: big ? 22 : 15,
    hp, maxHp: hp, dmg,
    range: big ? 62 : 52, atkInterval: big ? 1.3 : 1.1,
    atkTimer: rand(0.1, 0.6), speed: 148 + rand(-10, 14),
    alive: true, wp: team === 'blue' ? 1 : LANE.length - 2,
    laneOff: rand(-40, 40), target: null, seed: rand(0, 10),
    walkT: rand(0, 10), stunT: 0, slowT: 0, atkAnim: 0
  };
  w.units.push(m);
  return m;
}

function updateMinion(m, dt) {
  m.stunT = Math.max(0, m.stunT - dt);
  m.slowT = Math.max(0, m.slowT - dt);
  m.atkAnim = Math.max(0, (m.atkAnim || 0) - dt);
  if (m.stunT > 0) return;
  m.atkTimer -= dt;

  const target = m.target;
  let valid = target && target.alive && target.team !== m.team;
  if (valid) {
    const d = dist(m.x, m.y, target.x, target.y);
    if (d > 280) valid = false;
  }
  if (!valid) m.target = null;

  if (!m.target) {
    m.target = nearestEnemy(m, 235, { skipProtected: true });
    if (!m.target && m.super) m.target = nearestEnemy(m, 360, { skipProtected: true, preferStructure: true });
  }

  if (m.target) {
    const d = dist(m.x, m.y, m.target.x, m.target.y);
    const reach = m.range + m.target.radius + m.radius * 0.4;
    if (d <= reach) {
      if (m.atkTimer <= 0) {
        m.atkTimer = m.atkInterval;
        m.atkAnim = 0.22;
        dealDamage(m.target, m.dmg, m);
        addEffect({
          type: 'slash', x: (m.x + m.target.x) / 2, y: (m.y + m.target.y) / 2 - 18,
          angle: Math.atan2(m.target.y - m.y, m.target.x - m.x),
          life: 0.22, t: 0, r: 20, width: 4,
          color: m.team === 'blue' ? 'rgba(190,255,240,.8)' : 'rgba(255,210,190,.8)'
        });
      }
      m.walkT = 0;
      return;
    }
    if (d <= 280) {
      moveUnit(m, norm(m.target.x - m.x, m.target.y - m.y), dt);
      return;
    }
  }

  /* 沿路前进 */
  let tgt = LANE[m.wp];
  if (!tgt) return;
  const tx = tgt.x, ty = tgt.y + m.laneOff;
  if (dist(m.x, m.y, tx, ty) < 70) {
    if (m.team === 'blue' && m.wp < LANE.length - 1) m.wp++;
    else if (m.team === 'red' && m.wp > 0) m.wp--;
    tgt = LANE[m.wp];
  }
  if (tgt) {
    const n = norm(tgt.x - m.x, tgt.y + m.laneOff - m.y);
    moveUnit(m, n, dt);
  }
}

function moveUnit(u, dir, dt, speedMul = 1) {
  if (u.stunT > 0) return;
  let len = Math.hypot(dir.x, dir.y);
  if (len < 0.001) { u.walkT = 0; return; }
  const k = Math.min(1, len);
  let sp = (u.speed || 150) * speedMul * k;
  if (u.slowT > 0) sp *= 0.52;
  if (u.hasteT > 0) sp *= 1.2;
  u.x = clamp(u.x + (dir.x / len) * sp * dt, 70, WORLD.w - 70);
  u.y = clamp(u.y + (dir.y / len) * sp * dt, 90, WORLD.h - 90);
  if (Math.abs(dir.x) > 0.15) u.facing = dir.x > 0 ? 1 : -1;
  u.walkT += dt;
}

function separateUnits() {
  const foot = world.units.filter(u => u.alive && (u.kind === 'hero' || u.kind === 'minion'));
  for (let i = 0; i < foot.length; i++) {
    for (let j = i + 1; j < foot.length; j++) {
      const a = foot[i], b = foot[j];
      if (a.team !== b.team) continue;
      const minD = (a.radius + b.radius) * 0.72;
      const dx = b.x - a.x, dy = b.y - a.y;
      const d = Math.hypot(dx, dy);
      if (d > 0.001 && d < minD) {
        const push = (minD - d) * 0.5;
        const nx = dx / d, ny = dy / d;
        a.x = clamp(a.x - nx * push, 70, WORLD.w - 70);
        a.y = clamp(a.y - ny * push, 90, WORLD.h - 90);
        b.x = clamp(b.x + nx * push, 70, WORLD.w - 70);
        b.y = clamp(b.y + ny * push, 90, WORLD.h - 90);
      }
    }
  }
}

/* ---------------- 英雄 ---------------- */
function updateHero(h, dt) {
  h.hurtT = Math.max(0, h.hurtT - dt);
  h.thornT = Math.max(0, (h.thornT || 0) - dt);
  h.atkAnim = Math.max(0, h.atkAnim - dt);
  h.castAnim = Math.max(0, h.castAnim - dt);
  h.spinT = Math.max(0, h.spinT - dt);
  h.deathT = Math.max(0, h.deathT - dt);
  h.stunT = Math.max(0, h.stunT - dt);
  h.slowT = Math.max(0, h.slowT - dt);
  h.hasteT = Math.max(0, h.hasteT - dt);
  h.invulnT = Math.max(0, h.invulnT - dt);
  if (h.buffT > 0) { h.buffT -= dt; if (h.buffT <= 0) h.buffT = 0; }
  for (let i = 0; i < 3; i++) if (h.cds[i] > 0) h.cds[i] = Math.max(0, h.cds[i] - dt);
  if (h.shieldT > 0) {
    h.shieldT -= dt;
    if (h.shieldT <= 0) { h.shieldT = 0; h.shield = 0; }
  }

  if (!h.alive) {
    h.respawnT -= dt;
    if (h.respawnT <= 0) respawnHero(h);
    return;
  }

  /* 泉水恢复 */
  const base = world.bases[h.team];
  if (dist(h.x, h.y, base.x, base.y) < 250) {
    h.hp = Math.min(h.maxHp, h.hp + h.maxHp * 0.07 * dt);
  }

  /* 输入 / AI */
  let dir = { x: 0, y: 0 };
  if (h.stunT <= 0) {
    if (h.isPlayer && !world.autoPlayer) dir = playerInputDir();
    else dir = aiThink(h, dt);
  }
  h.moveDir = dir;
  if (Math.abs(dir.x) > 0.01 || Math.abs(dir.y) > 0.01) {
    h.lastDir = norm(dir.x, dir.y);
    moveUnit(h, dir, dt);
    if (!world.headless) {
      h.stepT -= dt;
      if (h.stepT <= 0) {
        h.stepT = 0.24;
        const dx = h.x - h.facing * (7 + rand(-3, 3)), dy = h.y + 3;
        if (!fxDust(dx, dy, h.team === 'blue' ? '#d6f0da' : '#f6dedc')) {
          addEffect({
            type: 'dust', x: dx, y: dy,
            life: 0.5, t: 0, size: rand(5, 8), seed: rand(0, TAU),
            color: h.team === 'blue' ? 'rgba(214,240,218,.55)' : 'rgba(246,222,205,.5)'
          });
        }
      }
    }
  } else {
    h.walkT = 0;
    h.stepT = 0;
  }

  /* 自动攻击 */
  h.atkTimer = Math.max(0, h.atkTimer - dt);
  if (h.stunT <= 0) {
    const target = findAttackTarget(h);
    if (target && h.atkTimer <= 0) {
      heroAutoAttack(h, target);
    }
  }
}

function playerInputDir() {
  let x = 0, y = 0;
  if (keys.has('a') || keys.has('arrowleft')) x -= 1;
  if (keys.has('d') || keys.has('arrowright')) x += 1;
  if (keys.has('w') || keys.has('arrowup')) y -= 1;
  if (keys.has('s') || keys.has('arrowdown')) y += 1;
  if (x || y) return { x, y };
  if (joy.active) return { x: joy.dx, y: joy.dy };
  return { x: 0, y: 0 };
}

function findAttackTarget(h) {
  let best = null, bd = Infinity;
  for (const u of world.units) {
    if (!u.alive || u.team === h.team || u.team === 'neutral') continue;
    const d = dist(h.x, h.y, u.x, u.y);
    if (u.kind === 'tower' && isTowerProtected(u)) continue;
    if (u.kind === 'base' && isBaseProtected(u)) continue;
    const reach = h.range + u.radius + h.radius * 0.25;
    if (d <= reach && d < bd) { bd = d; best = u; }
  }
  return best;
}

function heroAutoAttack(h, target) {
  h.atkTimer = h.atkInterval;
  h.atkAnim = ANIM_DUR.atk(h);
  const d = HERO_DEFS[h.heroId];
  if (Math.abs(target.x - h.x) > 10) h.facing = target.x >= h.x ? 1 : -1;
  h.atkKind = h.range > 160 ? 2 : 1;
  if (h.range > 160) {
    spawnHomingShot(h, target, {
      x: h.x, y: h.y - 28,
      dmg: h.damage, speed: 560, life: 1.6,
      color: h.heroId === 'fox' ? '#ffe0a0' : '#ffeaf1',
      size: 5, style: 'star'
    });
    Sound.play('shoot');
  } else {
    dealDamage(target, h.damage, h);
    addEffect({
      type: 'slash', x: (h.x + target.x) / 2, y: h.y - 24,
      angle: Math.atan2(target.y - h.y, target.x - h.x),
      life: 0.24, t: 0, r: 42, width: 6.5, color: 'rgba(255,242,200,.95)'
    });
    Sound.play('hit');
  }
}

function respawnHero(h) {
  h.alive = true;
  h.hp = h.maxHp;
  h.shield = 0; h.shieldT = 0; h.stunT = 0; h.slowT = 0;
  h.invulnT = 2;
  h.atkTimer = 0.3;
  h.deathT = 0; h.hitDir = 1; h.stepT = 0;
  h.atkAnim = 0; h.castAnim = 0; h.hurtT = 0;
  placeHeroAtBase(h, h.isPlayer ? 0 : randInt(1, 2));
  h.ai.retreat = false;
  addEffect({ type: 'beam', x: h.x, y: h.y, life: 0.9, t: 0, color: h.team === 'blue' ? 'rgba(150,245,230,.8)' : 'rgba(255,190,170,.8)' });
  addEffect({ type: 'ring', x: h.x, y: h.y, r0: 10, r1: 80, life: 0.6, t: 0, color: '#ffe7a8', width: 4 });
  if (h.isPlayer) showToast('回来啦！泉水帮你恢复了能量');
}

/* ---------------- AI ---------------- */
function aiThink(h, dt) {
  const ai = h.ai;
  ai.think -= dt;
  ai.skillTimer -= dt;
  const hpP = h.hp / h.maxHp;

  if (!ai.retreat && hpP < 0.3) ai.retreat = true;
  if (ai.retreat && hpP > 0.76) ai.retreat = false;

  const ownBase = world.bases[h.team];
  if (ai.retreat) {
    const d = dist(h.x, h.y, ownBase.x, ownBase.y);
    /* 兔子低血量会先给自己治疗 */
    if (h.heroId === 'rabbit' && h.cds[1] <= 0 && hpP < 0.55) castSkill(h, 1);
    if (d < 200) return { x: 0, y: 0 };
    return norm(ownBase.x - h.x, ownBase.y - h.y);
  }

  const pushReady = countAlliedMinions(h, 460) > 0 || world.heroes.every(o => o.team === h.team || !o.alive);
  let target = findAiTarget(h, pushReady);
  if (target && (target.kind === 'base' && isBaseProtected(target))) target = null;
  if (target && (target.kind === 'tower' && isTowerProtected(target))) target = null;

  if (target) {
    ai.target = target;
    const d = dist(h.x, h.y, target.x, target.y);
    const desired = Math.max(h.range * 0.82, 84);
    let dir;
    if (d > desired) {
      dir = norm(target.x - h.x, target.y - h.y);
    } else if (d < desired * 0.5 && h.range > 170) {
      dir = norm(h.x - target.x, h.y - target.y);
    } else {
      ai.strafe += dt * 1.4;
      const perp = { x: -(target.y - h.y) / (d || 1), y: (target.x - h.x) / (d || 1) };
      dir = { x: perp.x * Math.sin(ai.strafe) * 0.5, y: perp.y * Math.sin(ai.strafe) * 0.5 };
    }

    /* 不顶着敌方塔硬冲 */
    if (target.kind !== 'tower' && target.kind !== 'base') {
      const towerThreat = enemyStructureAt(h.team, h.x + dir.x * 30, h.y + dir.y * 30, 340);
      if (towerThreat && !alliedMinionsNear(towerThreat, 280, h.team)) {
        dir = norm(h.x - towerThreat.x, h.y - towerThreat.y);
      }
    }

    if (ai.skillTimer <= 0 && d < 620) {
      ai.skillTimer = world.difficulty === 'easy' ? rand(0.75, 1.5) : rand(0.4, 0.9);
      aiTrySkills(h, target, d);
    }
    return dir;
  }

  /* 沿兵线推进 */
  let tgt = LANE[ai.wp] || LANE[LANE.length - 1];
  const tx = tgt.x, ty = tgt.y + ai.laneOff;
  if (dist(h.x, h.y, tx, ty) < 80) {
    if (h.team === 'blue' && ai.wp < LANE.length - 1) ai.wp++;
    else if (h.team === 'red' && ai.wp > 0) ai.wp--;
  }
  tgt = LANE[ai.wp] || LANE[LANE.length - 1];

  /* 塔前停下等兵 */
  const threat = enemyStructureAt(h.team, tgt.x, tgt.y, 360);
  if (threat && !alliedMinionsNear(threat, 300, h.team) && dist(h.x, h.y, threat.x, threat.y) < threat.range + 60) {
    return { x: 0, y: 0 };
  }
  return norm(tgt.x - h.x, tgt.y + ai.laneOff - h.y);
}

function countAlliedMinions(h, r) {
  let n = 0;
  for (const u of world.units) {
    if (!u.alive || u.team !== h.team || u.kind !== 'minion') continue;
    if (dist(h.x, h.y, u.x, u.y) <= r) n++;
  }
  return n;
}

function findAiTarget(h, pushReady) {
  let best = null, bs = Infinity;
  for (const u of world.units) {
    if (!u.alive || u.team === h.team || u.team === 'neutral') continue;
    if (u.kind === 'tower' && isTowerProtected(u)) continue;
    if (u.kind === 'base' && isBaseProtected(u)) continue;
    const d = dist(h.x, h.y, u.x, u.y) - u.radius * 0.4;
    if (d > 560) continue;
    let s = d;
    if (u.kind === 'hero') s -= 130;
    else if (u.kind === 'minion') s += 35;
    else if (u.kind === 'tower') s += pushReady ? -120 : 40;
    else if (u.kind === 'base') s += pushReady ? -170 : 60;
    if (s < bs) { bs = s; best = u; }
  }
  return best;
}

function allyCountNear(h, r) {
  let n = 0;
  for (const o of world.units) {
    if (!o.alive || o === h || o.team !== h.team) continue;
    if (o.kind !== 'hero' && o.kind !== 'minion') continue;
    if (dist(h.x, h.y, o.x, o.y) <= r) n++;
  }
  return n;
}

function alliedMinionsNear(unit, r, team) {
  for (const u of world.units) {
    if (!u.alive || u.kind !== 'minion' || u.team !== team) continue;
    if (dist(unit.x, unit.y, u.x, u.y) <= r) return true;
  }
  return false;
}

function enemyStructureAt(team, x, y, pad = 0) {
  for (const u of world.units) {
    if (!u.alive || u.team === team) continue;
    if (u.kind !== 'tower' && u.kind !== 'base') continue;
    if (u.kind === 'base' && isBaseProtected(u)) continue;
    if (u.kind === 'tower' && isTowerProtected(u)) continue;
    if (dist(x, y, u.x, u.y) <= u.range + pad) return u;
  }
  return null;
}

function aiTrySkills(h, target, d) {
  const ready = i => h.cds[i] <= 0;
  const hpP = h.hp / h.maxHp;
  if (h.heroId === 'tiger') {
    if (d < 320 && ready(0) && Math.random() < 0.8) castTowards(h, 0, target);
    else if (d < 195 && ready(1) && Math.random() < 0.8) castSkill(h, 1);
    if (h.level >= 2 && ready(2) && d < 250 && Math.random() < (hpP < 0.6 ? 0.8 : 0.4)) castSkill(h, 2);
  } else if (h.heroId === 'fox') {
    if (d < 520 && ready(0) && Math.random() < 0.85) castSkill(h, 0);
    if (h.level >= 2 && ready(2) && d < 580 && Math.random() < 0.55) castSkill(h, 2);
    if (ready(1)) {
      if (hpP < 0.45 && d < 220) {
        const away = norm(h.x - target.x, h.y - target.y);
        castSkill(h, 1, away);
      } else if (d > 360 && Math.random() < 0.22) {
        castTowards(h, 1, target);
      }
    }
  } else if (h.heroId === 'bear') {
    /* 熊：先手跳大砸人堆，平时拍开贴脸的敌人 */
    if (h.level >= 2 && ready(2) && d < 380 && Math.random() < 0.6) castSkill(h, 2);
    else if (d < 210 && ready(0) && Math.random() < 0.7) castSkill(h, 0);
    if (d < 300 && ready(1) && target && target.kind === 'hero' && Math.random() < 0.6) castSkill(h, 1);
  } else if (h.heroId === 'otter') {
    /* 水獭：远程丢水泡，血少时滑水脱身 */
    if (d < 500 && ready(0) && Math.random() < 0.8) castSkill(h, 0);
    if (ready(1)) {
      if (hpP < 0.42 && d < 240) {
        const away = norm(h.x - target.x, h.y - target.y);
        castSkill(h, 1, away);
      } else if (d > 300 && Math.random() < 0.2) {
        castTowards(h, 1, target);
      }
    }
    if (h.level >= 2 && ready(2) && d < 620 && Math.random() < 0.5) castSkill(h, 2);
  } else if (h.heroId === 'hedgehog') {
    /* 刺猬：一直放刺，被贴身才缩球 */
    if (d < 560 && ready(0) && Math.random() < 0.85) castTowards(h, 0, target);
    if (ready(1) && (hpP < 0.62 || d < 150)) castSkill(h, 1);
    if (h.level >= 2 && ready(2) && (d < 230 || hpP < 0.45) && Math.random() < 0.7) castSkill(h, 2);
  } else {
    if (d < 520 && ready(0) && Math.random() < 0.8) castSkill(h, 0);
    if (ready(1) && (hpP < 0.7 || allyNeedsHeal(h))) castSkill(h, 1);
    if (h.level >= 2 && ready(2) && (hpP < 0.55 || d < 270) && Math.random() < 0.7) castSkill(h, 2);
  }
}

function allyNeedsHeal(h) {
  for (const o of world.heroes) {
    if (!o.alive || o.team !== h.team) continue;
    if (dist(h.x, h.y, o.x, o.y) < 420 && o.hp / o.maxHp < 0.55) return true;
  }
  return false;
}

function castTowards(h, i, target) {
  const dir = norm(target.x - h.x, target.y - h.y);
  return castSkill(h, i, dir);
}

/* ---------------- 结构物 ---------------- */
function updateStructure(t, dt) {
  t.atkAnim = Math.max(0, (t.atkAnim || 0) - dt);
  t.hitT = Math.max(0, (t.hitT || 0) - dt);
  if (t.kind === 'base' && isBaseProtected(t)) { t.atkTimer = Math.max(t.atkTimer, 0.6); return; }
  t.atkTimer -= dt;
  if (t.atkTimer > 0) return;
  const target = towerChooseTarget(t);
  if (!target) return;
  t.atkTimer = t.atkInterval;
  t.atkAnim = 0.32;
  spawnHomingShot(t, target, {
    x: t.x, y: t.y - (t.kind === 'base' ? 120 : 130),
    dmg: t.dmg, speed: t.kind === 'base' ? 420 : 470, life: 2.4,
    color: t.team === 'blue' ? '#9df4ff' : '#ffc0b0',
    size: t.kind === 'base' ? 10 : 8, style: 'bolt'
  });
  Sound.play('shoot');
}

function towerChooseTarget(t) {
  let bestM = null, bd = Infinity, bestH = null, hd = Infinity;
  for (const u of world.units) {
    if (!u.alive || u.team === t.team || u.team === 'neutral') continue;
    const d = dist(t.x, t.y, u.x, u.y);
    if (d > t.range + u.radius) continue;
    if (u.kind === 'minion' && d < bd) { bd = d; bestM = u; }
    else if (u.kind === 'hero' && d < hd) { hd = d; bestH = u; }
  }
  return bestM || bestH;
}

/* ---------------- 地面减速区（熊的裂谷 / 水獭的水道） ---------------- */
function spawnZone(x, y, r, team, life, color, opt) {
  opt = opt || {};
  const z = { x, y, r, team, life, t: 0, color: color || 'rgba(120,200,255,.3)', slow: opt.slow == null ? 0.42 : opt.slow, dmg: opt.dmg || 0, tick: 0, source: opt.source || null };
  world.zones.push(z);
  return z;
}

function updateZones(dt) {
  if (!world.zones.length) return;
  const keep = [];
  for (const z of world.zones) {
    z.t += dt;
    if (z.t >= z.life) continue;
    z.tick -= dt;
    if (z.tick <= 0) {
      z.tick = 0.22;
      for (const u of world.units) {
        if (!u.alive || u.team === z.team || u.team === 'neutral') continue;
        if (u.kind === 'tower' || u.kind === 'base') continue;
        if (dist(z.x, z.y, u.x, u.y - 10) > z.r + u.radius) continue;
        u.slowT = Math.max(u.slowT, 0.4);
        if (z.dmg) dealDamage(u, z.dmg, z.source);
      }
    }
    keep.push(z);
  }
  world.zones = keep;
}

/* ---------------- 投射物 ---------------- */
function spawnHomingShot(source, target, opt) {
  const p = {
    team: source.team, source, target,
    x: opt.x != null ? opt.x : source.x,
    y: opt.y != null ? opt.y : source.y - 26,
    vx: 0, vy: 0,
    speed: opt.speed || 520, dmg: opt.dmg || 20,
    life: opt.life || 2, homing: true,
    color: opt.color || '#ffe6a3', size: opt.size || 6,
    style: opt.style || 'bolt', splash: opt.splash || 0,
    splashRadius: opt.splashRadius || 0,
    pierce: opt.pierce || 0, hit: new Set()
  };
  const n = norm(target.x - p.x, target.y - 20 - p.y);
  p.vx = n.x * p.speed; p.vy = n.y * p.speed;
  world.projectiles.push(p);
  return p;
}

function spawnStraightShot(source, dir, opt) {
  const p = {
    team: source.team, source, target: null,
    x: source.x, y: source.y - 26,
    vx: dir.x * (opt.speed || 600), vy: dir.y * (opt.speed || 600),
    speed: opt.speed || 600, dmg: opt.dmg || 20,
    life: opt.life || 1.4, homing: false,
    color: opt.color || '#ffe6a3', size: opt.size || 6,
    style: opt.style || 'star', splash: opt.splash || 0,
    splashRadius: opt.splashRadius || 0,
    pierce: opt.pierce || 0, hit: new Set(), slow: opt.slow || 0
  };
  world.projectiles.push(p);
  return p;
}

function updateProjectiles(dt) {
  const alive = [];
  for (const p of world.projectiles) {
    p.life -= dt;
    if (p.life <= 0) continue;

    if (p.homing && p.target && p.target.alive) {
      const tx = p.target.x, ty = p.target.y - 20;
      const n = norm(tx - p.x, ty - p.y);
      p.vx = n.x * p.speed;
      p.vy = n.y * p.speed;
    }
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    if (p.x < -60 || p.x > WORLD.w + 60 || p.y < -80 || p.y > WORLD.h + 80) continue;

    let hit = null;
    for (const u of world.units) {
      if (!u.alive || u.team === p.team || u.team === 'neutral') continue;
      if (p.hit.has(u)) continue;
      if (dist(p.x, p.y, u.x, u.y - 18) < u.radius + p.size + 5) { hit = u; break; }
    }
    if (!hit) { alive.push(p); continue; }

    if (p.splash > 0) {
      for (const u of world.units) {
        if (!u.alive || u.team === p.team || u.team === 'neutral') continue;
        if (dist(p.x, p.y, u.x, u.y - 18) <= p.splashRadius + u.radius) {
          dealDamage(u, p.dmg, p.source || p);
          if (p.slow) u.slowT = Math.max(u.slowT, p.slow);
        }
      }
      addEffect({ type: 'burst', x: p.x, y: p.y, r: p.splashRadius, count: 12, color: p.color, life: 0.45, t: 0, seed: rand(0, TAU) });
      addEffect({ type: 'ring', x: p.x, y: p.y, r0: 10, r1: p.splashRadius, color: p.color, life: 0.4, t: 0, width: 5 });
      world.shake = Math.max(world.shake, 5);
      Sound.play('hit');
      continue;
    }

    dealDamage(hit, p.dmg, p.source || p);
    if (p.slow) hit.slowT = Math.max(hit.slowT, p.slow);
    p.hit.add(hit);
    addEffect({ type: 'burst', x: p.x, y: p.y, r: 26, count: 5, color: p.color, life: 0.3, t: 0, seed: rand(0, TAU) });
    if (p.pierce > 0) {
      p.pierce--;
      alive.push(p);
    }
  }
  world.projectiles = alive;
}

/* ---------------- 伤害与击杀 ---------------- */
function dealDamage(target, amount, source, skipThorn) {
  if (!target || !target.alive) return 0;
  /* 尖尖的刺球：打它的人会被扎回去（skipThorn 防止无限递归） */
  if (!skipThorn && target.thornT > 0 && target.kind === 'hero' && source && source.alive && source.kind === 'hero' && source !== target) {
    addEffect({
      type: 'hitSpark', x: source.x, y: source.y - 46, life: 0.22, t: 0,
      dir: source.x >= target.x ? 1 : -1, color: '#ffd9a8', seed: rand(0, TAU)
    });
    dealDamage(source, 24 + (target.level || 1) * 5, target, true);
  }
  if (target.kind === 'hero' && target.invulnT > 0) return 0;

  if (target.kind === 'tower' && isTowerProtected(target)) {
    showShieldHint('先拆掉外塔，才能打内塔哦！');
    addEffect({ type: 'ring', x: target.x, y: target.y - 80, r0: 60, r1: 92, color: 'rgba(255,244,190,.8)', life: 0.35, t: 0, width: 4 });
    return 0;
  }
  if (target.kind === 'base' && isBaseProtected(target)) {
    showShieldHint('水晶被保护着，先拆掉两座蘑菇塔！');
    addEffect({ type: 'ring', x: target.x, y: target.y - 80, r0: 60, r1: 100, color: 'rgba(255,244,190,.8)', life: 0.35, t: 0, width: 4 });
    return 0;
  }

  let dmg = amount;
  if (source && source.kind === 'hero') {
    dmg *= source.dmgScale || 1;
    if (source.buffT > 0) dmg *= 1.2;
    if (source.isPlayer) dmg *= 1.02;
  }
  if (target.kind === 'tower' || target.kind === 'base') {
    if (source && source.kind === 'minion') dmg *= 1.5;
    else if (source && source.kind === 'hero') dmg *= 1.2;
    if (world.time > 480) dmg *= 1.5;
    else if (world.time > 360) dmg *= 1.2;
  }
  dmg = Math.max(1, Math.round(dmg));

  /* 护盾吸收 */
  let absorbed = 0;
  if (target.shield > 0) {
    absorbed = Math.min(target.shield, dmg);
    target.shield -= absorbed;
    dmg -= absorbed;
    if (target.shield <= 0) { target.shield = 0; target.shieldT = 0; }
  }
  if (dmg > 0) {
    target.hp -= dmg;
    if (target.kind === 'hero') {
      target.hurtT = ANIM_DUR.hurt(target);
      if (source && Math.abs(target.x - source.x) > 2) target.hitDir = target.x >= source.x ? 1 : -1;
      if (target.isPlayer) world.shake = Math.max(world.shake, 3.5);
      if (source && source.isPlayer) {
        world.shake = Math.max(world.shake, 2.5);
        /* 我打中别人：一小段顿帧 + 镜头微推，读起来才是"打到了" */
        world.hitstop = Math.max(world.hitstop, 0.045);
        world.zoomPunch = Math.max(world.zoomPunch, 0.5);
      }
      if (target.isPlayer && source && source.kind === 'hero') {
        /* 被打中更痛：顿帧更长 */
        world.hitstop = Math.max(world.hitstop, 0.06);
        world.zoomPunch = Math.max(world.zoomPunch, 0.85);
      }
      if (!world.headless) {
        const spark = {
          x: target.x, y: target.y - 46, dir: target.hitDir,
          color: target.team === 'blue' ? '#c9fbff' : '#ffd0bc',
          big: !!(source && source.isPlayer)
        };
        /* WebGL 粒子可用就交给 Phaser，否则退回 Canvas 特效 */
        if (!fxHit(spark.x, spark.y, spark)) {
          addEffect(Object.assign({ type: 'hitSpark', life: 0.26, t: 0, seed: rand(0, TAU) }, spark));
        }
      }
    } else if (target.kind === 'tower' || target.kind === 'base') {
      target.hitT = 0.2;
      if (!world.headless && source && (source.isPlayer || Math.random() < 0.35)) {
        addEffect({
          type: 'hitSpark', x: target.x + rand(-18, 18), y: target.y - (target.kind === 'base' ? 100 : 100),
          life: 0.24, t: 0, dir: source.x <= target.x ? 1 : -1,
          color: '#ffe4a2', seed: rand(0, TAU), big: source.isPlayer
        });
      }
    }
    queueDamageText(target, dmg, source);
  }

  if (target.hp <= 0) killUnit(target, source);
  return dmg;
}


/* 伤害数字：同一目标 0.16 秒内合并成一次，避免糊成一团 */
function queueDamageText(target, amount, source) {
  const interested = target.kind === 'hero' || target.kind === 'tower' || target.kind === 'base' || (source && source.isPlayer);
  if (!interested) return;
  if (!target.dmgBatch) {
    const batch = { amount: 0, source, seq: (target.textSeq = (target.textSeq || 0) + 1) };
    target.dmgBatch = batch;
    world.timers.push({
      t: 0.16,
      fn: () => {
        if (target.dmgBatch !== batch) return;
        target.dmgBatch = null;
        spawnDamageText(target, batch.amount, batch.source, batch.seq);
      }
    });
  }
  target.dmgBatch.amount += amount;
  target.dmgBatch.source = source;
}

function spawnDamageText(target, amount, source, seq) {
  /* 混战时数字太多会糊成一片，超过 12 个就不再补新的 */
  let live = 0;
  for (const e of world.effects) if (e.type === 'text' && e.text && e.text[0] !== '回') live++;
  if (live >= 12) return;
  const playerSide = (source && source.isPlayer) || target.isPlayer;
  const blueSource = source && source.team === 'blue';
  const color = blueSource
    ? (playerSide ? '#fff0a0' : '#eaffd8')
    : (playerSide ? '#ff9f8d' : '#ffd6c4');
  const baseY = target.kind === 'hero' ? 108 : target.kind === 'minion' ? 48 : 172;
  const side = seq % 2 ? 1 : -1;
  addEffect({
    type: 'text',
    x: target.x + side * (14 + (seq % 3) * 7),
    y: target.y - baseY - (seq % 3) * 21,
    dx: side * rand(10, 26),
    text: '-' + Math.round(amount),
    color,
    size: playerSide ? 16 : 13,
    life: 0.72,
    t: 0
  });
}

function showShieldHint(text) {
  if (world.headless) return;
  if (world.shieldToastT > 0) return;
  world.shieldToastT = 4;
  showToast(text);
}

function killUnit(u, source) {
  if (!u.alive) return;
  u.alive = false;
  u.hp = 0;
  const killerTeam = source && source.team && source.team !== 'neutral' ? source.team : enemyOf(u.team);

  if (u.kind === 'hero') {
    u.deaths++;
    u.respawnT = 5 + u.level * 0.3;
    u.shield = 0;
    u.deathT = ANIM_DUR.death(u);
    addEffect({ type: 'burst', x: u.x, y: u.y - 40, r: 80, count: 14, color: '#ffe6a3', life: 0.7, t: 0, seed: rand(0, TAU) });
    addEffect({ type: 'ring', x: u.x, y: u.y, r0: 12, r1: 76, color: 'rgba(255,246,210,.75)', life: 0.5, t: 0, width: 5, squash: 0.5 });
    addEffect({ type: 'petalFall', x: u.x, y: u.y - 60, life: 1, t: 0, seed: rand(0, TAU), color: u.team === 'blue' ? '#bdf6ee' : '#ffc8b8' });
    addEffect({ type: 'text', x: u.x, y: u.y - 120, text: '回泉水休息', color: '#fff3cf', size: 15, life: 1, t: 0 });
    grantXpAround(u.x, u.y, 100, killerTeam);
    if (source && source.kind === 'hero' && source.team === killerTeam) {
      source.kills++;
      grantXp(source, 35);
    }
    world.kills[killerTeam]++;
    const killerName = source && source.kind === 'hero' ? HERO_DEFS[source.heroId].name : '塔';
    addKillFeed(killerName, killerTeam, HERO_DEFS[u.heroId].name, u.team);
    Sound.play('kill');
    world.shake = Math.max(world.shake, 9);
    world.hitstop = Math.max(world.hitstop, 0.09);
    world.zoomPunch = Math.max(world.zoomPunch, 1);
    if (u.isPlayer) {
      showToast('被送回家休息啦，别灰心！几秒后就能重新出发');
    }
    return;
  }

  if (u.kind === 'minion') {
    addEffect({ type: 'burst', x: u.x, y: u.y - 16, r: u.big ? 46 : 30, count: 7, color: u.team === 'blue' ? '#a5f0ea' : '#ffcabc', life: 0.4, t: 0, seed: rand(0, TAU) });
    grantXpAround(u.x, u.y, u.big ? 38 : 22, killerTeam);
    Sound.play('hit');
    return;
  }

  if (u.kind === 'tower') {
    world.towerKills[killerTeam]++;
    world.superMinions[killerTeam]++;
    grantXpAround(u.x, u.y, 120, killerTeam);
    addEffect({ type: 'burst', x: u.x, y: u.y - 110, r: 150, count: 20, color: u.team === 'blue' ? '#9ef0f5' : '#ffc0ad', life: 0.9, t: 0, seed: rand(0, TAU) });
    addEffect({ type: 'ring', x: u.x, y: u.y - 80, r0: 20, r1: 190, color: '#ffeab0', life: 0.8, t: 0, width: 7 });
    world.shake = Math.max(world.shake, 14);
    world.hitstop = Math.max(world.hitstop, 0.11);
    world.zoomPunch = Math.max(world.zoomPunch, 1.3);
    Sound.play('tower');
    const isEnemyTower = u.team !== player.team;
    showToast(isEnemyTower ? '拆掉敌方蘑菇塔啦！继续加油！' : '我们的蘑菇塔被拆掉了，回防一下吧！');
    if (!world.headless) addKillFeed(killerTeam === 'blue' ? '蓝队' : '红队', killerTeam, '蘑菇塔', u.team);
    /* 全队护罩解除提示 */
    const enemyTeam = u.team;
    if (!world.towers[enemyTeam].some(t => t.alive) && !world.baseOpened[enemyTeam]) {
      world.baseOpened[enemyTeam] = true;
      if (!world.headless) {
        showToast(enemyTeam === 'red' ? '敌方水晶的护罩消失啦！冲向水晶！' : '我方水晶的护罩消失了，快回来守护！', 3200);
      }
    }
    return;
  }

  if (u.kind === 'base') {
    addEffect({ type: 'burst', x: u.x, y: u.y - 90, r: 240, count: 26, color: '#ffe6a3', life: 1.2, t: 0, seed: rand(0, TAU) });
    world.shake = Math.max(world.shake, 18);
    endGame(enemyOf(u.team));
  }
}

function endGame(winner) {
  if (world.over) return;
  world.over = true;
  world.winner = winner;
  world.overTimer = 1.6;
  Sound.play(winner === 'blue' ? 'win' : 'lose');
}

function grantXpAround(x, y, amount, team) {
  const avg = t => {
    const arr = world.heroes.filter(h => h.team === t);
    return arr.reduce((s, h) => s + h.level, 0) / Math.max(1, arr.length);
  };
  const behind = Math.max(0, avg(enemyOf(team)) - avg(team));
  const boost = 1 + Math.min(0.35, behind * 0.12);
  for (const h of world.heroes) {
    if (!h.alive || h.team !== team) continue;
    if (dist(h.x, h.y, x, y) <= 900) grantXp(h, Math.round(amount * boost));
  }
}

function grantXp(h, amount) {
  if (h.level >= MAX_LEVEL) return;
  h.xp += amount;
  while (h.level < MAX_LEVEL && h.xp >= XP_TABLE[h.level]) {
    h.level++;
    const d = HERO_DEFS[h.heroId];
    const oldMax = h.maxHp;
    h.maxHp = d.hp + d.growthHp * (h.level - 1);
    h.hp = Math.min(h.maxHp, h.hp + (h.maxHp - oldMax) + h.maxHp * 0.1);
    h.damage = d.damage + d.growthDmg * (h.level - 1);
    addEffect({ type: 'ring', x: h.x, y: h.y - 40, r0: 12, r1: 100, color: '#ffe08a', life: 0.6, t: 0, width: 5 });
    addEffect({ type: 'burst', x: h.x, y: h.y - 40, r: 65, count: 10, color: '#ffe9a8', life: 0.6, t: 0, seed: rand(0, TAU) });
    if (h.isPlayer) {
      showLevelUp();
      Sound.play('level');
    }
  }
}

function healUnit(u, amount) {
  if (!u.alive) return 0;
  const before = u.hp;
  u.hp = Math.min(u.maxHp, u.hp + amount);
  const healed = Math.round(u.hp - before);
  if (healed > 0) {
    addEffect({
      type: 'text', x: u.x + rand(-8, 8), y: u.y - 92, dx: rand(-14, 14),
      text: '+' + healed, color: '#a5f7bd', size: 16, life: 0.75, t: 0
    });
  }
  return healed;
}

/* ---------------- 技能 ---------------- */
function skillPower(h, base) {
  return base * (1 + 0.15 * (h.level - 1));
}

function castSkill(h, i, dirOverride) {
  if (!h || !h.alive || !world || world.over) return false;
  if (world.countdown > 0) return false;
  const def = HERO_DEFS[h.heroId];
  const sk = def.skills[i];
  if (sk.ult && h.level < 2) {
    if (h.isPlayer) showToast('升到 2 级就能放大招啦！');
    return false;
  }
  if (h.cds[i] > 0) {
    if (h.isPlayer) Sound.play('nope');
    return false;
  }
  if (h.stunT > 0) return false;

  let dir = dirOverride;
  if (!dir) {
    if (Math.hypot(h.moveDir.x, h.moveDir.y) > 0.2) dir = norm(h.moveDir.x, h.moveDir.y);
    else if (h.isPlayer) dir = h.facing >= 0 ? { x: 1, y: 0 } : { x: -1, y: 0 };
    else dir = h.lastDir || { x: h.facing, y: 0 };
  }

  h.cds[i] = sk.cd;
  h.castAnim = ANIM_DUR.cast(h);
  h.castId = i;
  if (Math.abs(dir.x) > 0.15) h.facing = dir.x >= 0 ? 1 : -1;
  if (h.isPlayer) world.shake = Math.max(world.shake, sk.ult ? 6 : 2.5);

  const power = base => skillPower(h, base);
  const doAoe = (x, y, r, dmg, color, extra) => {
    for (const u of world.units) {
      if (!u.alive || u.team === h.team) continue;
      if (dist(x, y, u.x, u.y - 14) <= r + u.radius) {
        dealDamage(u, dmg, h);
        if (extra) extra(u);
      }
    }
  };

  if (h.heroId === 'tiger') {
    if (i === 0) {
      const fromX = h.x, fromY = h.y;
      const toX = clamp(h.x + dir.x * 250, 80, WORLD.w - 80);
      const toY = clamp(h.y + dir.y * 250, 100, WORLD.h - 100);
      h.x = toX; h.y = toY;
      h.invulnT = Math.max(h.invulnT, 0.18);
      addEffect({ type: 'dashTrail', x1: fromX, y1: fromY - 20, x2: toX, y2: toY - 20, life: 0.35, t: 0, color: 'rgba(255,226,160,.85)' });
      addEffect({ type: 'burst', x: toX, y: toY - 20, r: 55, count: 8, color: '#ffe4a0', life: 0.4, t: 0, seed: rand(0, TAU) });
      for (const u of world.units) {
        if (!u.alive || u.team === h.team) continue;
        if (segDist(u.x, u.y, fromX, fromY, toX, toY) < 55 + u.radius) {
          dealDamage(u, power(120), h);
          u.stunT = Math.max(u.stunT, 0.35);
          const nx = u.x + dir.x * 26, ny = u.y + dir.y * 26;
          u.x = clamp(nx, 70, WORLD.w - 70);
          u.y = clamp(ny, 90, WORLD.h - 90);
        }
      }
      Sound.play('skill');
      world.shake = Math.max(world.shake, 6);
    } else if (i === 1) {
      addEffect({ type: 'ring', x: h.x, y: h.y - 20, r0: 20, r1: 200, color: '#ffe9a8', life: 0.55, t: 0, width: 9, squash: 0.7 });
      doAoe(h.x, h.y, 200, power(100), null, u => { if (u.kind === 'minion') u.stunT = Math.max(u.stunT, 0.3); });
      h.shield = Math.max(h.shield, h.maxHp * 0.28);
      h.shieldT = Math.max(h.shieldT, 4);
      for (const o of world.heroes) {
        if (o === h || !o.alive || o.team !== h.team) continue;
        if (dist(h.x, h.y, o.x, o.y) < 260) {
          o.shield = Math.max(o.shield, o.maxHp * 0.14);
          o.shieldT = Math.max(o.shieldT, 3.5);
        }
      }
      addEffect({ type: 'text', x: h.x, y: h.y - 112, text: '护盾！', color: '#bff4ff', size: 15, life: 0.8, t: 0 });
      Sound.play('skill');
    } else {
      h.spinT = ANIM_DUR.spin(h);
      addEffect({ type: 'ring', x: h.x, y: h.y - 10, r0: 20, r1: 210, color: '#ffdaa0', life: 0.5, t: 0, width: 8, squash: 0.7 });
      for (let k = 0; k < 3; k++) {
        world.timers.push({
          t: k * 0.26,
          fn: () => {
            if (!h.alive || world.over) return;
            addEffect({ type: 'ring', x: h.x, y: h.y - 10, r0: 30, r1: 195, color: '#ffe0a0', life: 0.4, t: 0, width: 7, squash: 0.72 });
            doAoe(h.x, h.y, 195, power(92));
            for (const u of world.units) {
              if (!u.alive || u.team === h.team) continue;
              if (dist(h.x, h.y, u.x, u.y - 14) <= 195 + u.radius && u.kind !== 'tower' && u.kind !== 'base') {
                u.slowT = Math.max(u.slowT, 0.5);
              }
            }
            Sound.play('hit');
          }
        });
      }
      Sound.play('ult');
      world.shake = Math.max(world.shake, 9);
    }
    return true;
  }

  if (h.heroId === 'fox') {
    if (i === 0) {
      const target = nearestEnemy(h, 560, { skipProtected: true });
      if (target) {
        spawnHomingShot(h, target, {
          x: h.x, y: h.y - 30, dmg: power(165), speed: 480, life: 2.2,
          color: '#ffb15c', size: 9, style: 'fire',
          splash: 1, splashRadius: 118
        });
      } else {
        spawnStraightShot(h, dir, {
          dmg: power(165), speed: 480, life: 1.6, color: '#ffb15c',
          size: 9, style: 'fire', splash: 1, splashRadius: 110
        });
      }
      addEffect({ type: 'spark', x: h.x + dir.x * 24, y: h.y - 40, life: 0.3, t: 0, color: '#ffd08a' });
      Sound.play('skill');
    } else if (i === 1) {
      const fromX = h.x, fromY = h.y;
      const toX = clamp(h.x + dir.x * 230, 80, WORLD.w - 80);
      const toY = clamp(h.y + dir.y * 230, 100, WORLD.h - 100);
      h.x = toX; h.y = toY;
      h.invulnT = Math.max(h.invulnT, 0.35);
      addEffect({ type: 'dashTrail', x1: fromX, y1: fromY - 28, x2: toX, y2: toY - 28, life: 0.3, t: 0, color: 'rgba(200,180,255,.9)' });
      addEffect({ type: 'ring', x: toX, y: toY - 20, r0: 10, r1: 120, color: '#cdb4ff', life: 0.45, t: 0, width: 6 });
      doAoe(toX, toY, 125, power(85), null, u => { u.slowT = Math.max(u.slowT, 0.7); });
      Sound.play('skill');
    } else {
      const target = nearestEnemy(h, 720, { preferHero: true, skipProtected: true });
      const cx = target ? target.x : h.x + dir.x * 300;
      const cy = target ? target.y : h.y + dir.y * 300;
      const offs = [{ x: -80, y: 30 }, { x: 70, y: -20 }, { x: 0, y: 83 }];
      const baseDelay = 0.72;
      offs.forEach((off, k) => {
        const mx = clamp(cx + off.x, 120, WORLD.w - 120);
        const my = clamp(cy + off.y, 140, WORLD.h - 120);
        addEffect({ type: 'warn', x: mx, y: my, r: 122, life: baseDelay + k * 0.26, t: 0, color: '#ffd08a' });
        addEffect({ type: 'meteor', x: mx, y: my, life: baseDelay + k * 0.26, t: 0 });
        world.timers.push({
          t: baseDelay + k * 0.26,
          fn: () => {
            if (world.over) return;
            addEffect({ type: 'burst', x: mx, y: my, r: 130, count: 14, color: '#ffd88a', life: 0.6, t: 0, seed: rand(0, TAU) });
            addEffect({ type: 'ring', x: mx, y: my, r0: 20, r1: 150, color: '#ffcf8a', life: 0.55, t: 0, width: 8, squash: 0.75 });
            for (const u of world.units) {
              if (!u.alive || u.team === h.team) continue;
              if (dist(mx, my, u.x, u.y - 14) <= 128 + u.radius) {
                dealDamage(u, power(135), h);
                u.slowT = Math.max(u.slowT, 0.6);
              }
            }
            world.shake = Math.max(world.shake, 5);
            Sound.play('tower');
          }
        });
      });
      Sound.play('ult');
      world.shake = Math.max(world.shake, 7);
    }
    return true;
  }

  if (h.heroId === 'bear') {
    if (i === 0) {
      /* 荷叶拍击：拍飞面前一片，是拆团和保护队友的手段 */
      const cx = h.x + dir.x * 92, cy = h.y + dir.y * 92;
      addEffect({ type: 'ring', x: cx, y: cy - 16, r0: 26, r1: 120, color: 'rgba(186,226,158,.92)', life: 0.42, t: 0, width: 11, squash: 0.66 });
      addEffect({ type: 'burst', x: cx, y: cy - 16, r: 70, count: 9, color: '#cbe8ad', life: 0.42, t: 0, seed: rand(0, TAU) });
      for (const u of world.units) {
        if (!u.alive || u.team === h.team || u.kind === 'tower' || u.kind === 'base') continue;
        if (dist(cx, cy, u.x, u.y - 12) > 104 + u.radius) continue;
        dealDamage(u, power(96), h);
        u.slowT = Math.max(u.slowT, 1.1);
        const n = norm(u.x - h.x, u.y - h.y);
        u.x = clamp(u.x + n.x * 48, 70, WORLD.w - 70);
        u.y = clamp(u.y + n.y * 48, 90, WORLD.h - 90);
      }
      Sound.play('skill');
      world.shake = Math.max(world.shake, 5);
    } else if (i === 1) {
      /* 熊抱一下：把最近的敌人拉进怀里抱住 */
      let tgt = null, bd = 300;
      for (const o of world.heroes) {
        if (o === h || !o.alive || o.team === h.team) continue;
        const d = dist(h.x, h.y, o.x, o.y);
        if (d < bd) { bd = d; tgt = o; }
      }
      if (!tgt) {
        addEffect({ type: 'text', x: h.x, y: h.y - 116, text: '抱不到人…', color: '#ffe9c8', size: 14, life: 0.7, t: 0 });
      } else {
        const n = norm(h.x - tgt.x, h.y - tgt.y);
        addEffect({ type: 'dashTrail', x1: tgt.x, y1: tgt.y - 20, x2: h.x - n.x * 62, y2: h.y - n.y * 62, life: 0.3, t: 0, color: 'rgba(200,235,180,.8)' });
        tgt.x = clamp(h.x - n.x * 62, 70, WORLD.w - 70);
        tgt.y = clamp(h.y - n.y * 62, 90, WORLD.h - 90);
        tgt.stunT = Math.max(tgt.stunT, 0.7);
        dealDamage(tgt, power(72), h);
        h.shield = Math.max(h.shield, h.maxHp * 0.18);
        h.shieldT = Math.max(h.shieldT, 3);
        addEffect({ type: 'text', x: h.x, y: h.y - 118, text: '抱住了！', color: '#dff3c8', size: 15, life: 0.8, t: 0 });
      }
      Sound.play('skill');
    } else {
      /* 山崩地裂：跳向敌人最密处砸地，留下减速裂谷 */
      const fromX = h.x, fromY = h.y;
      let tx = clamp(h.x + dir.x * 230, 90, WORLD.w - 90);
      let ty = clamp(h.y + dir.y * 230, 110, WORLD.h - 110);
      let best = null, bs = 1e9;
      for (const o of world.heroes) {
        if (!o.alive || o.team === h.team) continue;
        const d = dist(h.x, h.y, o.x, o.y);
        if (d < 360 && d < bs) { bs = d; best = o; }
      }
      if (best) { tx = clamp(best.x, 90, WORLD.w - 90); ty = clamp(best.y, 110, WORLD.h - 110); }
      h.x = tx; h.y = ty;
      h.invulnT = Math.max(h.invulnT, 0.25);
      addEffect({ type: 'dashTrail', x1: fromX, y1: fromY - 24, x2: tx, y2: ty - 24, life: 0.36, t: 0, color: 'rgba(255,224,168,.75)' });
      Sound.play('ult');
      world.timers.push({
        t: 0.3,
        fn: () => {
          addEffect({ type: 'ring', x: tx, y: ty - 10, r0: 30, r1: 250, color: '#ffe0a8', life: 0.6, t: 0, width: 13, squash: 0.62 });
          addEffect({ type: 'burst', x: tx, y: ty - 14, r: 150, count: 18, color: '#e8c79a', life: 0.7, t: 0, seed: rand(0, TAU) });
          for (const u of world.units) {
            if (!u.alive || u.team === h.team || u.kind === 'neutral') continue;
            if (dist(tx, ty, u.x, u.y - 14) > 235 + u.radius) continue;
            dealDamage(u, power(u.kind === 'tower' || u.kind === 'base' ? 150 : 168), h);
            if (u.kind !== 'tower' && u.kind !== 'base') u.stunT = Math.max(u.stunT, 0.85);
          }
          spawnZone(tx, ty, 190, h.team, 3.4, 'rgba(126,86,52,.3)', { slow: 0.5, source: h });
          Sound.play('ult');
          world.shake = Math.max(world.shake, 13);
          world.hitstop = Math.max(world.hitstop, 0.1);
          world.zoomPunch = Math.max(world.zoomPunch, 1.2);
        }
      });
    }
    return true;
  }

  if (h.heroId === 'otter') {
    if (i === 0) {
      /* 大水泡：炸开一片水花减速 */
      spawnStraightShot(h, dir, {
        speed: 470, dmg: power(58), size: 13, color: '#bfe9ff', style: 'bubble',
        splash: power(62), splashRadius: 96, slow: 1.2, life: 1.6
      });
      Sound.play('shoot');
    } else if (i === 1) {
      /* 滑水冲刺：贴地滑一段，留下水道 */
      const fromX = h.x, fromY = h.y;
      const tx = clamp(h.x + dir.x * 215, 80, WORLD.w - 80);
      const ty = clamp(h.y + dir.y * 215, 100, WORLD.h - 100);
      h.x = tx; h.y = ty;
      h.invulnT = Math.max(h.invulnT, 0.16);
      addEffect({ type: 'dashTrail', x1: fromX, y1: fromY - 18, x2: tx, y2: ty - 18, life: 0.34, t: 0, color: 'rgba(180,235,255,.85)' });
      for (let k = 0; k < 3; k++) {
        const t = k / 2;
        spawnZone(lerp(fromX, tx, t), lerp(fromY, ty, t), 74, h.team, 2.4, 'rgba(96,190,225,.24)', { slow: 0.45, source: h });
      }
      Sound.play('skill');
    } else {
      /* 瀑布冲击：三波水帘砸在敌人最密的地方 */
      let cx = h.x + dir.x * 200, cy = h.y + dir.y * 200;
      let best = null, bs = -1;
      for (const o of world.heroes) {
        if (!o.alive || o.team === h.team) continue;
        let near = 0;
        for (const q of world.heroes) if (q.alive && q.team !== h.team && dist(o.x, o.y, q.x, q.y) < 230) near++;
        if (near > bs) { bs = near; best = o; }
      }
      if (best) { cx = best.x; cy = best.y; }
      cx = clamp(cx, 120, WORLD.w - 120);
      cy = clamp(cy, 140, WORLD.h - 140);
      Sound.play('ult');
      for (let k = 0; k < 3; k++) {
        world.timers.push({
          t: 0.22 + k * 0.3,
          fn: () => {
            const ox = cx + rand(-70, 70), oy = cy + rand(-50, 50);
            addEffect({ type: 'warn', x: ox, y: oy, r: 118, life: 0.22, t: 0, color: 'rgba(120,210,245,.9)' });
            addEffect({ type: 'ring', x: ox, y: oy - 12, r0: 24, r1: 150, color: '#a8e6ff', life: 0.5, t: 0, width: 10, squash: 0.6 });
            addEffect({ type: 'burst', x: ox, y: oy - 20, r: 110, count: 14, color: '#cdefff', life: 0.6, t: 0, seed: rand(0, TAU) });
            for (const u of world.units) {
              if (!u.alive || u.team === h.team) continue;
              if (dist(ox, oy, u.x, u.y - 14) > 132 + u.radius) continue;
              dealDamage(u, power(u.kind === 'tower' || u.kind === 'base' ? 96 : 118), h);
              if (u.kind !== 'tower' && u.kind !== 'base') {
                u.slowT = Math.max(u.slowT, 1.5);
                const n = norm(u.x - ox, u.y - oy);
                u.x = clamp(u.x + n.x * 26, 70, WORLD.w - 70);
                u.y = clamp(u.y + n.y * 26, 90, WORLD.h - 90);
              }
            }
            Sound.play('tower');
            world.shake = Math.max(world.shake, 8);
          }
        });
      }
      spawnZone(cx, cy, 170, h.team, 2.8, 'rgba(96,190,225,.22)', { slow: 0.45, source: h });
    }
    return true;
  }

  if (h.heroId === 'hedgehog') {
    if (i === 0) {
      /* 三连尖刺：扇形射出三根，会穿透一个小怪 */
      const base = Math.atan2(dir.y, dir.x);
      for (let k = -1; k <= 1; k++) {
        const a = base + k * 0.15;
        spawnStraightShot(h, { x: Math.cos(a), y: Math.sin(a) }, {
          speed: 620, dmg: power(46), size: 7, color: k === 0 ? '#ffe6b0' : '#ffd0a8',
          style: 'spike', pierce: 1, life: 1.1
        });
      }
      Sound.play('shoot');
    } else if (i === 1) {
      /* 缩成刺球：护盾 + 反伤，谁打谁被扎 */
      h.shield = Math.max(h.shield, h.maxHp * 0.26);
      h.shieldT = Math.max(h.shieldT, 3.5);
      h.thornT = 3.5;
      addEffect({ type: 'ring', x: h.x, y: h.y - 34, r0: 20, r1: 74, color: '#ffd9a8', life: 0.5, t: 0, width: 6 });
      addEffect({ type: 'text', x: h.x, y: h.y - 116, text: '扎手！', color: '#ffe1b0', size: 15, life: 0.8, t: 0 });
      Sound.play('skill');
    } else {
      /* 万刺齐发：向四周炸开，离得越近越痛 */
      h.spinT = ANIM_DUR.spin(h);
      addEffect({ type: 'ring', x: h.x, y: h.y - 30, r0: 18, r1: 150, color: '#ffe6b0', life: 0.5, t: 0, width: 8 });
      for (let k = 0; k < 12; k++) {
        const a = (k / 12) * TAU;
        spawnStraightShot(h, { x: Math.cos(a), y: Math.sin(a) }, {
          speed: 540, dmg: power(52), size: 7, color: '#ffdda6', style: 'spike', pierce: 1, life: 1.3
        });
      }
      for (const u of world.units) {
        if (!u.alive || u.team === h.team) continue;
        if (dist(h.x, h.y, u.x, u.y - 14) > 150 + u.radius) continue;
        dealDamage(u, power(96), h);
        if (u.kind !== 'tower' && u.kind !== 'base') {
          u.stunT = Math.max(u.stunT, 0.3);
          const n = norm(u.x - h.x, u.y - h.y);
          u.x = clamp(u.x + n.x * 34, 70, WORLD.w - 70);
          u.y = clamp(u.y + n.y * 34, 90, WORLD.h - 90);
        }
      }
      Sound.play('ult');
      world.shake = Math.max(world.shake, 9);
    }
    return true;
  }

  /* 兔子朵朵 */
  if (i === 0) {
    const target = nearestEnemy(h, 640, { skipProtected: true });
    let ddir = dir;
    if (target) ddir = norm(target.x - h.x, target.y - h.y);
    spawnStraightShot(h, ddir, {
      dmg: power(82), speed: 660, life: 1.3, color: '#ffc9db',
      size: 7, style: 'dart', pierce: 3, slow: 1.2
    });
    Sound.play('shoot');
  } else if (i === 1) {
    addEffect({ type: 'ring', x: h.x, y: h.y - 20, r0: 15, r1: 220, color: '#a5f7c4', life: 0.6, t: 0, width: 7, squash: 0.7 });
    addEffect({ type: 'heal', x: h.x, y: h.y - 20, r: 45, count: 6, color: '#9ff2b4', life: 0.8, t: 0, seed: rand(0, TAU) });
    for (const o of world.heroes) {
      if (!o.alive || o.team !== h.team) continue;
      if (dist(h.x, h.y, o.x, o.y) <= 440) {
        healUnit(o, o.maxHp * 0.18);
        o.hasteT = Math.max(o.hasteT, 3);
        addEffect({ type: 'heal', x: o.x, y: o.y - 20, r: 38, count: 4, color: '#b4f7c5', life: 0.7, t: 0, seed: rand(0, TAU) });
      }
    }
    Sound.play('heal');
  } else {
    addEffect({ type: 'ring', x: h.x, y: h.y - 30, r0: 20, r1: 330, color: '#ffe6a0', life: 0.9, t: 0, width: 10, squash: 0.72 });
    addEffect({ type: 'burst', x: h.x, y: h.y - 50, r: 150, count: 16, color: '#fff0b8', life: 0.9, t: 0, seed: rand(0, TAU) });
    for (const o of world.heroes) {
      if (!o.alive || o.team !== h.team) continue;
      healUnit(o, o.maxHp * 0.12);
      o.shield = Math.max(o.shield, o.maxHp * 0.2);
      o.shieldT = Math.max(o.shieldT, 4);
      addEffect({ type: 'ring', x: o.x, y: o.y - 30, r0: 20, r1: 60, color: '#bff4ff', life: 0.5, t: 0, width: 4 });
    }
    for (const u of world.units) {
      if (!u.alive || u.team === h.team) continue;
      if (dist(h.x, h.y, u.x, u.y - 20) <= 280 + u.radius) {
        dealDamage(u, power(130), h);
        u.slowT = Math.max(u.slowT, 1.2);
      }
    }
    Sound.play('ult');
    world.shake = Math.max(world.shake, 6);
  }
  return true;
}

function segDist(px, py, x1, y1, x2, y2) {
  const dx = x2 - x1, dy = y2 - y1;
  const l2 = dx * dx + dy * dy || 1;
  let t = ((px - x1) * dx + (py - y1) * dy) / l2;
  t = clamp(t, 0, 1);
  return Math.hypot(px - (x1 + t * dx), py - (y1 + t * dy));
}

function nearestEnemy(from, range, opt = {}) {
  let best = null, bd = range;
  for (const u of world.units) {
    if (!u.alive || u.team === from.team || u.team === 'neutral') continue;
    const d = dist(from.x, from.y, u.x, u.y);
    if (d > range + u.radius) continue;
    let score = d;
    if (opt.preferHero && u.kind === 'hero') score -= 150;
    if (opt.preferStructure && (u.kind === 'tower' || u.kind === 'base')) score -= 260;
    if (opt.skipProtected) {
      if (u.kind === 'tower' && isTowerProtected(u)) continue;
      if (u.kind === 'base' && isBaseProtected(u)) continue;
    }
    if (score < bd) { bd = score; best = u; }
  }
  return best;
}

/* ---------------- 蜂蜜 ---------------- */
function updatePickups(dt) {
  for (const p of world.pickups) {
    if (!p.alive) {
      p.respawnT -= dt;
      if (p.respawnT <= 0) {
        p.alive = true;
        addEffect({ type: 'ring', x: p.x, y: p.y, r0: 8, r1: 56, color: '#ffe3a0', life: 0.6, t: 0, width: 4 });
      }
      continue;
    }
    for (const h of world.heroes) {
      if (!h.alive) continue;
      if (dist(h.x, h.y, p.x, p.y) < p.radius + h.radius + 4) {
        p.alive = false;
        p.respawnT = 34;
        healUnit(h, h.maxHp * 0.2);
        h.buffT = 15;
        grantXp(h, 30);
        addEffect({ type: 'burst', x: p.x, y: p.y - 24, r: 55, count: 10, color: '#ffe08a', life: 0.6, t: 0, seed: rand(0, TAU) });
        Sound.play('collect');
        if (h.isPlayer) showToast('甜甜的蜂蜜！攻击力提升 15 秒');
        break;
      }
    }
  }
}

/* ---------------- 计时器 / 特效 ---------------- */
function updateTimers(dt) {
  if (!world.timers.length) return;
  const remain = [];
  for (const t of world.timers) {
    t.t -= dt;
    if (t.t <= 0) { try { t.fn(); } catch (e) { console.warn(e); } }
    else remain.push(t);
  }
  world.timers = remain;
}
function addEffect(e) {
  e.t = e.t || 0;
  world.effects.push(e);
}
function updateEffects(dt) {
  if (!world.effects.length) return;
  world.effects = world.effects.filter(e => {
    e.t += dt;
    return e.t < e.life;
  });
}

/* 镜头缩放：屏幕氛围与命中缩放脉冲共用，updateCamera 与 renderWorld 必须取同一个值 */
function camScale(cw, ch) {
  const punch = world && world.zoomPunch ? 1 + world.zoomPunch * 0.035 : 1;
  return Math.max(ch / 650, cw / 1020) * punch;
}

/* ---------------- 镜头 ---------------- */
function updateCamera(dt, snap) {
  if (!world) return;
  const cw = battleCanvas ? battleCanvas.clientWidth : window.innerWidth;
  const ch = battleCanvas ? battleCanvas.clientHeight : window.innerHeight;
  if (!cw || !ch) return;
  const scale = camScale(cw, ch);
  Cam.scale = scale;
  const vw = cw / scale, vh = ch / scale;
  const focus = player && (player.alive || player.deathT > 0)
    ? player
    : { x: world.bases.blue.x, y: world.bases.blue.y };
  let tx = focus.x + (focus === player && player ? player.moveDir.x * 55 : 0);
  let ty = focus.y - 40 + (focus === player && player ? player.moveDir.y * 35 : 0);
  tx = vw >= WORLD.w ? WORLD.w / 2 : clamp(tx, vw / 2, WORLD.w - vw / 2);
  ty = vh >= WORLD.h ? WORLD.h / 2 : clamp(ty, vh / 2, WORLD.h - vh / 2);
  if (snap) {
    Cam.x = tx; Cam.y = ty;
  } else {
    const k = 1 - Math.pow(0.0025, dt);
    Cam.x = lerp(Cam.x, tx, k);
    Cam.y = lerp(Cam.y, ty, k);
  }
}

/* ============================================================
   渲染
   ============================================================ */
function resizeCanvas() {
  if (!battleCanvas) return;
  const w = battleCanvas.clientWidth || window.innerWidth;
  const h = battleCanvas.clientHeight || window.innerHeight;
  const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
  PIXEL_RATIO = Math.min(window.devicePixelRatio || 1, coarse ? 1.5 : 2);
  if (typeof w3dResize === 'function') w3dResize(w, h);
  const nw = Math.round(w * PIXEL_RATIO), nh = Math.round(h * PIXEL_RATIO);
  if (battleCanvas.width !== nw || battleCanvas.height !== nh) {
    battleCanvas.width = nw;
    battleCanvas.height = nh;
  }
}

/* 渲染模式：?render=2d 强制回退；默认有 WebGL 就上 3D */
function pickRenderer() {
  const q = new URLSearchParams(location.search);
  const want = q.get('render');
  if (want === '2d') return false;
  if (want === '3d') return true;
  return typeof w3dAvailable === 'function' ? w3dAvailable() : false;
}

function renderWorld(timeSec) {
  if (!world || !ctx) return;
  const dt3 = Math.min(0.05, Math.max(0.001, timeSec - (W3D._lastT || timeSec)));
  W3D._lastT = timeSec;
  if (App.render3D && W3D.ok) {
    w3dFrame(world, timeSec, dt3);
    renderOverlay2D(timeSec);
    return;
  }
  const cw = battleCanvas.clientWidth, ch = battleCanvas.clientHeight;
  if (!cw || !ch) return;
  if (battleCanvas.width !== Math.round(cw * PIXEL_RATIO) || battleCanvas.height !== Math.round(ch * PIXEL_RATIO)) resizeCanvas();

  ctx.setTransform(PIXEL_RATIO, 0, 0, PIXEL_RATIO, 0, 0);
  ctx.clearRect(0, 0, cw, ch);

  const scale = camScale(cw, ch);
  Cam.scale = scale;
  const vw = cw / scale, vh = ch / scale;
  RenderView = { x: Cam.x, y: Cam.y, w: vw, h: vh };

  FxView.w = cw; FxView.h = ch; FxView.scale = scale; FxView.cx = Cam.x; FxView.cy = Cam.y;
  const shakeX = world.shake > 0.1 ? (Math.random() - 0.5) * world.shake : 0;
  const shakeY = world.shake > 0.1 ? (Math.random() - 0.5) * world.shake : 0;

  ctx.save();
  FxView.sx = shakeX; FxView.sy = shakeY;
  ctx.translate(cw / 2 + shakeX, ch / 2 + shakeY);
  ctx.scale(scale, scale);
  ctx.translate(-Cam.x, -Cam.y);

  /* 背景 */
  ctx.fillStyle = '#7ac69a';
  ctx.fillRect(Cam.x - vw / 2 - 40, Cam.y - vh / 2 - 40, vw + 80, vh + 80);
  if (bgCanvas) {
    const sx = clamp(Cam.x - vw / 2, 0, WORLD.w);
    const sy = clamp(Cam.y - vh / 2, 0, WORLD.h);
    const ex = clamp(Cam.x + vw / 2, 0, WORLD.w);
    const ey = clamp(Cam.y + vh / 2, 0, WORLD.h);
    if (ex > sx && ey > sy) ctx.drawImage(bgCanvas, sx, sy, ex - sx, ey - sy, sx, sy, ex - sx, ey - sy);
  }

  drawCloudShadows(ctx, world.time);
  drawRiverLife(ctx, world.time);

  /* 地面警示 */
  for (const e of world.effects) if (e.type === 'warn') drawEffect(ctx, e, world.time);

  for (const z of world.zones) {
    if (pointInView(z.x, z.y, z.r + 120)) drawZone(ctx, z, world.time);
  }

  /* 蜂蜜 */
  for (const p of world.pickups) {
    if (p.alive && pointInView(p.x, p.y, 120)) drawHoneySprite(ctx, p, world.time);
  }

  /* 建筑先画，避免盖住英雄 */
  for (const b of [world.bases.blue, world.bases.red]) {
    if (b.alive && pointInView(b.x, b.y, 300)) drawBaseSprite(ctx, b, world.time);
  }
  for (const t of [...world.towers.blue, ...world.towers.red]) {
    if (t.alive && pointInView(t.x, t.y, 260)) drawTowerSprite(ctx, t, world.time);
  }

  /* 单位按 y 排序（阵亡英雄保留 1 秒灵魂动画） */
  const foot = world.units.filter(u =>
    (u.alive || (u.kind === 'hero' && u.deathT > 0)) &&
    (u.kind === 'hero' || u.kind === 'minion'));
  foot.sort((a, b) => a.y - b.y);
  for (const u of foot) {
    if (!pointInView(u.x, u.y, 200)) continue;
    if (u.kind === 'hero') drawHeroSprite(ctx, u, world.time);
    else drawMinionSprite(ctx, u, world.time);
  }

  /* 投射物 */
  for (const p of world.projectiles) {
    if (pointInView(p.x, p.y, 100)) drawProjectile(ctx, p);
  }

  /* 特效 */
  for (const e of world.effects) {
    if (e.type !== 'warn') drawEffect(ctx, e, world.time);
  }

  /* 氛围 */
  drawAmbient(ctx, world.petals, world.time);
  drawButterflies(ctx, world.time);

  /* 血条与名字 */
  for (const t of [...world.towers.blue, ...world.towers.red]) {
    if (t.alive && pointInView(t.x, t.y, 260)) drawUnitHud(ctx, t, world.time);
  }
  for (const b of [world.bases.blue, world.bases.red]) {
    if (b.alive && pointInView(b.x, b.y, 300)) drawUnitHud(ctx, b, world.time);
  }
  for (const p of world.pickups) {
    if (p.alive && pointInView(p.x, p.y, 120)) drawUnitHud(ctx, p, world.time);
  }
  for (const u of foot) {
    if (!u.alive || !pointInView(u.x, u.y, 200)) continue;
    drawUnitHud(ctx, u, world.time);
  }

  ctx.restore();

  /* 全屏光影：阳光、树影、低血量红晕 */
  drawScreenMood(ctx, cw, ch, world.time, timeSec);

  /* 摇杆 */
  if (player && player.alive && world.started && !world.over) {
    drawJoystick(ctx, joy, cw, ch);
  }

  /* 小地图 */
  if (minimapCtx) drawMinimap(minimapCtx, 220, 120, world, world.time);
}

/* ============================================================
   3D 模式下的 2D 叠加层
   ------------------------------------------------------------
   文字与血条留在 2D 画：任何 DPR 下都清晰，不会被 3D 拉伸糊掉。
   做法是把世界点投影到屏幕，再把绘制原点平移过去，
   于是 render.js 里的 HUD/特效代码可以原样复用。
   ============================================================ */
const OVERLAY_SCALE = 1.35;

function overlayAt(x, y, h, fn) {
  const sp = w3dProject(x, y, h);
  if (!sp || !sp.on) return;
  const ctx = renderCtxRef;
  ctx.save();
  ctx.translate(sp.x, sp.y);
  ctx.scale(OVERLAY_SCALE, OVERLAY_SCALE);
  ctx.translate(-x, -y);
  fn();
  ctx.restore();
}

function renderOverlay2D(timeSec) {
  const cw = battleCanvas.clientWidth, ch = battleCanvas.clientHeight;
  ctx.setTransform(PIXEL_RATIO, 0, 0, PIXEL_RATIO, 0, 0);
  ctx.clearRect(0, 0, cw, ch);

  /* 特效：地面环类已由 3D 画过，这里只画空中的 */
  for (const e of world.effects) {
    if (e.type === 'ring' || e.type === 'warn') continue;
    const gy = e.gy == null ? e.y : e.gy;
    const hh = e.h == null ? 34 : e.h;
    overlayAt(e.x, gy, hh, () => drawEffect(ctx, e, world.time));
  }

  /* 血条与名字 */
  const hudOf = (u, above) => {
    if (!u.alive) return;
    overlayAt(u.x, u.y, above, () => drawUnitHud(ctx, u, world.time));
  };
  for (const t of [...world.towers.blue, ...world.towers.red]) hudOf(t, 150);
  for (const b of [world.bases.blue, world.bases.red]) hudOf(b, 210);
  for (const p of world.pickups) if (p.alive) hudOf(p, 60);
  for (const u of world.units) {
    if (u.kind !== 'hero' || !u.alive) continue;
    hudOf(u, 118);
  }

  drawScreenMood(ctx, cw, ch, world.time, timeSec);
  if (player && player.alive && world.started && !world.over) drawJoystick(ctx, joy, cw, ch);
  if (minimapCtx) drawMinimap(minimapCtx, 220, 120, world, world.time);
}

/* ============================================================
   HUD
   ============================================================ */
function updateSkillHUD() {
  if (!player) return;
  const def = HERO_DEFS[player.heroId];
  ui.skillButtons.forEach((btn, i) => {
    const cd = player.cds[i] || 0;
    const total = def.skills[i].cd;
    btn.style.setProperty('--cd', cd > 0 ? (cd / total * 100).toFixed(1) : '0');
    btn.classList.toggle('is-cooling', cd > 0);
    const txt = btn.querySelector('.cd-text');
    if (txt) txt.textContent = cd > 0 ? (cd >= 1 ? Math.ceil(cd) : cd.toFixed(1)) : '';
    const locked = i === 2 && player.level < 2;
    btn.classList.toggle('is-locked', locked);
    btn.classList.toggle('is-ready', cd <= 0 && !locked && player.alive);
  });
}

function updateHUD() {
  if (!world || !player || world.headless) return;
  ui.hudHpFill.style.width = clamp(player.hp / player.maxHp, 0, 1) * 100 + '%';
  ui.hudHpText.textContent = Math.max(0, Math.ceil(player.hp)) + ' / ' + Math.round(player.maxHp);
  ui.hudLvl.textContent = player.level;
  const lo = XP_TABLE[player.level - 1] || 0;
  const hi = XP_TABLE[player.level] != null ? XP_TABLE[player.level] : (XP_TABLE[XP_TABLE.length - 1] + 1);
  ui.hudXpFill.style.width = clamp((player.xp - lo) / Math.max(1, hi - lo), 0, 1) * 100 + '%';
  ui.scoreBlue.textContent = world.kills.blue;
  ui.scoreRed.textContent = world.kills.red;
  ui.matchClock.textContent = fmtTime(world.time);
  if (!App.objectiveHidden && world.time > 14) { App.objectiveHidden = true; ui.objective.classList.add('is-faded'); }
  if (!App.tipHidden && world.time > 9) { App.tipHidden = true; ui.battleTip.classList.add('is-hidden'); }
  if (world.time > 12) ui.joystickHint.classList.add('is-hidden');
  if (player.level !== App.lastLevel) {
    App.lastLevel = player.level;
    if (player.level >= 2) ui.ultLock.textContent = '大招就绪';
  }
}

function showCountdown(text) {
  if (!ui.countdown) return;
  ui.countdown.textContent = text;
  ui.countdown.style.fontSize = text.length > 1 ? 'clamp(46px,10vh,96px)' : '';
  ui.countdown.classList.remove('is-pop');
  void ui.countdown.offsetWidth;
  ui.countdown.classList.add('is-pop');
}

function showLevelUp() {
  if (!ui.levelupBanner) return;
  ui.levelupBanner.textContent = player && player.level >= 2 ? '升级啦！大招已解锁' : '升级啦！';
  ui.levelupBanner.classList.remove('is-show');
  void ui.levelupBanner.offsetWidth;
  ui.levelupBanner.classList.add('is-show');
}

let toastTimer = null;
function showToast(text, duration = 2300) {
  if (!world || world.headless || !ui.battleToast) return;
  ui.battleToast.textContent = text;
  ui.battleToast.classList.add('is-show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => ui.battleToast.classList.remove('is-show'), duration);
}

function addKillFeed(killerName, killerTeam, victimName, victimTeam) {
  if (!world || world.headless || !ui.killfeed) return;
  const d = document.createElement('div');
  d.className = 'feed-item';
  d.innerHTML = `<span class="${killerTeam === 'blue' ? 'b' : 'r'}">${killerName}</span> <span class="star">★</span> 击败了 <span class="${victimTeam === 'blue' ? 'b' : 'r'}">${victimName}</span>`;
  ui.killfeed.appendChild(d);
  while (ui.killfeed.children.length > 3) ui.killfeed.firstChild.remove();
  setTimeout(() => d.remove(), 3200);
}

/* ============================================================
   界面流程
   ============================================================ */
function showScreen(name) {
  /* 特效层只在战斗界面开启；Phaser 启动失败则保持隐藏 */
  if (typeof W3D !== 'undefined') {
      const host = document.getElementById('world3dHost');
      if (host) host.style.display = name === 'battle' ? 'block' : 'none';
      /* 3D 渲染器等真进战斗、容器有尺寸后再建：省显存，也避免在菜单里创建 GL 上下文 */
      if (name === 'battle' && App.render3D && !W3D.ok && !W3D.error && host) {
        if (!w3dInit(host)) {
          console.warn('[3D] 初始化失败，自动退回 2D 画面');
          App.render3D = false;
        } else if (battleCanvas) {
          w3dResize(battleCanvas.clientWidth, battleCanvas.clientHeight);
        }
      }
    }
  if (typeof StageFX !== 'undefined' && !App.render3D) {
    /* 必须先让容器有尺寸，否则 WebGL 帧缓冲为 0 会启动失败 */
    StageFX.setEnabled(name === 'battle');
    if (name === 'battle') requestAnimationFrame(() => StageFX.boot());
  }
  Object.entries(ui.screens).forEach(([key, el]) => {
    if (el) el.classList.toggle('is-active', key === name);
  });
  App.screen = name;
  if (name !== 'battle') {
    clearKeys();
    joy.active = false;
  }
}

function applySoundState() {
  Sound.enabled = App.sound;
  document.body.classList.toggle('sound-off', !App.sound);
  if (ui.btnSoundPause) ui.btnSoundPause.textContent = App.sound ? '音效：开' : '音效：关';
}

function toggleSound() {
  App.sound = !App.sound;
  applySoundState();
  try { localStorage.setItem('ta_sound', App.sound ? '1' : '0'); } catch (e) {}
  if (App.sound) { Sound.init(); Sound.play('ui'); }
}

function renderHeroCards() {
  const wrap = ui.heroCards;
  if (!wrap) return;
  wrap.innerHTML = '';
  HERO_ORDER.forEach(id => {
    const d = HERO_DEFS[id];
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'hero-card' + (id === App.hero ? ' is-picked' : '');
    card.dataset.hero = id;
    card.setAttribute('role', 'option');
    card.setAttribute('aria-selected', id === App.hero ? 'true' : 'false');
    card.innerHTML = `
      <div class="card-art">
        ${d.ribbon ? '<div class="card-ribbon">' + d.ribbon + '</div>' : ''}
        <img src="${d.img}" alt="${d.name}" draggable="false">
        <div class="card-check">✓</div>
        <div class="card-art-info">
          <span class="card-art-name">${d.name}</span>
          <span class="card-art-title">${d.title}</span>
        </div>
      </div>
      <div class="card-body">
        <span class="role-chip">${d.role}</span>
        <span class="diff-dots" title="上手难度">${[0, 1, 2].map(i => `<i class="${i < d.difficulty ? 'on' : ''}"></i>`).join('')}</span>
      </div>`;
    card.addEventListener('click', () => selectHero(id, true));
    wrap.appendChild(card);
  });
}

function selectHero(id, fromClick) {
  App.hero = id;
  try { localStorage.setItem('ta_hero', id); } catch (e) {}
  $$('.hero-card').forEach(card => {
    const on = card.dataset.hero === id;
    card.classList.toggle('is-picked', on);
    card.setAttribute('aria-selected', on ? 'true' : 'false');
  });
  renderHeroDetail(id);
  if (fromClick) Sound.play('click');
}

function renderHeroDetail(id) {
  const d = HERO_DEFS[id];
  ui.detailRole.textContent = d.role;
  ui.detailDiff.innerHTML = [0, 1].map(i => `<i class="${i < d.difficulty ? 'on' : ''}"></i>`).join('');
  ui.detailName.textContent = d.name;
  ui.detailTitle.textContent = d.title;
  ui.detailTagline.textContent = d.tagline;
  ui.detailHp.textContent = d.hp;
  ui.detailAtk.textContent = d.damage;
  ui.detailRange.textContent = d.range > 160 ? '远程' : '近战';
  const keys = ['Q', 'W', 'E'];
  ui.detailSkills.innerHTML = d.skills.map((sk, i) => `
    <div class="skill-row ${sk.ult ? 'ult' : ''}" style="--c1:${d.skillColors[i][0]};--c2:${d.skillColors[i][1]}">
      <span class="mini-ico">${skillIcon(sk.icon)}</span>
      <div class="sk-txt">
        <div class="sk-name"><b>${keys[i]}</b>${sk.name}</div>
        <div class="sk-desc">${sk.desc}</div>
      </div>
    </div>`).join('');
}

function syncBattleHUD() {
  const d = HERO_DEFS[App.hero];
  ui.hudAvatar.src = d.img;
  if (ui.pauseAvatar) ui.pauseAvatar.src = d.img;
  const keys = ['Q', 'W', 'E'];
  ui.skillButtons.forEach((btn, i) => {
    const sk = d.skills[i];
    btn.querySelector('.ico').innerHTML = skillIcon(sk.icon);
    btn.querySelector('.skill-name').textContent = sk.name;
    btn.querySelector('kbd').textContent = keys[i];
    btn.style.setProperty('--c1', d.skillColors[i][0]);
    btn.style.setProperty('--c2', d.skillColors[i][1]);
    btn.classList.remove('is-cooling', 'is-ready', 'is-locked');
  });
  ui.ultLock.textContent = '2级解锁';
}

function startBattle(opts = {}) {
  const heroId = opts.hero || App.hero;
  App.hero = heroId;
  App.difficulty = opts.difficulty || App.difficulty;
  App.paused = false;
  App.resultShown = false;
  App.lastLevel = 1;
  App.tipHidden = false;
  App.objectiveHidden = false;
  App.battleId++;

  if (!bgCanvas) bgCanvas = buildBackground();
  world = createWorld(heroId, App.difficulty, !!opts.auto);
  player = world.heroes.find(h => h.isPlayer);

  syncBattleHUD();
  ui.killfeed.innerHTML = '';
  ui.objective.classList.remove('is-faded');
  ui.battleTip.classList.remove('is-hidden');
  ui.joystickHint.classList.remove('is-hidden');
  ui.levelupBanner.classList.remove('is-show');
  ui.battleToast.classList.remove('is-show');
  ui.countdown.textContent = '';
  ui.countdown.classList.remove('is-pop');
  ui.pauseOverlay.classList.remove('is-open');
  document.body.classList.remove('sound-off');
  applySoundState();

  showScreen('battle');
  resizeCanvas();
  updateCamera(0, true);
  resetJoystick();
  updateHUD();
  updateSkillHUD();
  Sound.init();
}

function resetJoystick() {
  joy.active = false;
  joy.id = null;
  joy.dx = 0;
  joy.dy = 0;
}

function pauseGame() {
  if (!world || world.over || App.screen !== 'battle' || world.countdown > 0) return;
  App.paused = true;
  ui.pauseOverlay.classList.add('is-open');
  Sound.play('ui');
}

function resumeGame() {
  App.paused = false;
  ui.pauseOverlay.classList.remove('is-open');
  Sound.play('ui');
}

function quitToHome() {
  App.paused = false;
  ui.pauseOverlay.classList.remove('is-open');
  world = null;
  player = null;
  showScreen('home');
}

function showResult() {
  if (!world || !player || App.resultShown) return;
  App.resultShown = true;
  const win = world.winner === 'blue';
  const stars = win ? (1 + (world.time <= 320 ? 1 : 0) + (player.deaths <= 1 ? 1 : 0)) : 0;

  ui['screen-result'].classList.toggle('is-lose', !win);
  ui.resultBadge.textContent = win ? '胜利' : '加油';
  ui.resultTitle.textContent = win
    ? pickOne(['漂亮！水晶点亮啦！', '我们一起赢啦！', '小英雄们真棒！'])
    : pickOne(['别灰心，再来一次！', '差一点点就赢了！', '小英雄们辛苦啦！']);
  ui.resultSub.textContent = win
    ? '你和小伙伴们一起守护了森林。'
    : '回泉水休息一下，下次一定能赢。';
  Array.from(ui.resultStars.children).forEach((el, i) => el.classList.toggle('on', i < stars));
  const d = HERO_DEFS[player.heroId];
  ui.resultAvatar.src = d.img;
  ui.resultHeroName.textContent = d.name;
  ui.resultHeroRole.textContent = d.role + ' · ' + d.title;
  ui.rsTime.textContent = fmtTime(world.time);
  ui.rsKills.textContent = player.kills;
  ui.rsDeaths.textContent = player.deaths;
  ui.rsTowers.textContent = world.towerKills.blue;

  spawnConfetti(win ? 34 : 0);
  showScreen('result');
  if (win) Sound.play('win');
}

function spawnConfetti(count) {
  const box = ui.resultConfetti;
  box.innerHTML = '';
  const colors = ['#ffd166', '#ff9f80', '#8fe0c8', '#b8d8ff', '#ffc2d9', '#fff0b8'];
  for (let i = 0; i < count; i++) {
    const s = document.createElement('span');
    s.style.left = rand(2, 98) + '%';
    s.style.background = pickOne(colors);
    s.style.width = rand(6, 11) + 'px';
    s.style.height = rand(9, 16) + 'px';
    s.style.animationDuration = rand(2.4, 4.2) + 's';
    s.style.animationDelay = rand(0, 1.2) + 's';
    s.style.setProperty('--dx', rand(-60, 60) + 'px');
    s.style.setProperty('--rot', rand(-720, 720) + 'deg');
    s.style.borderRadius = Math.random() > 0.5 ? '50%' : '3px';
    box.appendChild(s);
  }
}

/* ============================================================
   输入
   ============================================================ */
function clearKeys() { keys.clear(); }

function bindInput() {
  window.addEventListener('keydown', e => {
    const k = e.key.toLowerCase();
    if (App.screen === 'battle') {
      if (['q', 'w', 'e'].includes(k)) {
        e.preventDefault();
        if (!App.paused && world && world.started && !world.over) castSkill(player, ['q', 'w', 'e'].indexOf(k));
        return;
      }
      if (k === 'p' || k === 'escape') {
        e.preventDefault();
        if (App.paused) resumeGame(); else pauseGame();
        return;
      }
      if (['arrowup', 'arrowdown', 'arrowleft', 'arrowright', ' '].includes(k)) e.preventDefault();
      keys.add(k);
    }
  });
  window.addEventListener('keyup', e => keys.delete(e.key.toLowerCase()));
  window.addEventListener('blur', () => clearKeys());

  const c = battleCanvas;
  const pointerPos = e => {
    const r = c.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };
  c.addEventListener('pointerdown', e => {
    Sound.init();
    if (!world || App.screen !== 'battle' || App.paused || world.over || world.countdown > 0) return;
    const { x, y } = pointerPos(e);
    const w = c.clientWidth, h = c.clientHeight;
    if (x > w * 0.52) return;
    if (!player || !player.alive) return;
    joy.active = true;
    joy.id = e.pointerId;
    joy.bx = clamp(x, 90, w * 0.5);
    joy.by = clamp(y, 110, h - 90);
    joy.dx = 0; joy.dy = 0;
    try { c.setPointerCapture(e.pointerId); } catch (err) {}
    e.preventDefault();
  });
  c.addEventListener('pointermove', e => {
    if (!joy.active || e.pointerId !== joy.id) return;
    const { x, y } = pointerPos(e);
    const dx = x - joy.bx, dy = y - joy.by;
    const d = Math.hypot(dx, dy);
    const max = 62;
    if (d > max) { joy.dx = dx / d; joy.dy = dy / d; }
    else { joy.dx = dx / max; joy.dy = dy / max; }
    e.preventDefault();
  });
  const endPointer = e => {
    if (joy.active && e.pointerId === joy.id) resetJoystick();
  };
  c.addEventListener('pointerup', endPointer);
  c.addEventListener('pointercancel', endPointer);
  c.addEventListener('contextmenu', e => e.preventDefault());

  ui.skillButtons.forEach(btn => {
    btn.addEventListener('pointerdown', e => {
      e.preventDefault();
      Sound.init();
      if (!world || App.screen !== 'battle' || App.paused || world.over) return;
      castSkill(player, Number(btn.dataset.skill));
    });
  });
}

/* ============================================================
   初始化
   ============================================================ */
function loadPrefs() {
  try {
    const diff = localStorage.getItem('ta_diff');
    if (diff === 'normal' || diff === 'easy') App.difficulty = diff;
    const hero = localStorage.getItem('ta_hero');
    if (HERO_ORDER.includes(hero)) App.hero = hero;
    const sound = localStorage.getItem('ta_sound');
    if (sound === '0') App.sound = false;
  } catch (e) {}
}

function syncDifficultyUI() {
  $$('.seg').forEach(seg => seg.classList.toggle('is-on', seg.dataset.diff === App.difficulty));
  if (ui.selectDiffBadge) ui.selectDiffBadge.textContent = '难度 · ' + (App.difficulty === 'easy' ? '轻松' : '挑战');
}

function spawnPetals() {
  const box = ui.homePetals;
  if (!box) return;
  box.innerHTML = '';
  const colors = ['#ffd9df', '#ffe9b8', '#ffd0b8', '#fff6e8'];
  for (let i = 0; i < 12; i++) {
    const s = document.createElement('span');
    s.style.left = rand(2, 96) + '%';
    s.style.width = rand(7, 13) + 'px';
    s.style.height = rand(10, 17) + 'px';
    s.style.background = pickOne(colors);
    s.style.opacity = rand(0.35, 0.7);
    s.style.animationDuration = rand(9, 18) + 's';
    s.style.animationDelay = rand(-18, 0) + 's';
    s.style.borderRadius = Math.random() > 0.5 ? '100% 0 100% 0' : '0 100% 0 100%';
    box.appendChild(s);
  }
}

function openHelp() {
  if (ui.helpModal) ui.helpModal.classList.add('is-open');
  Sound.play('ui');
}
function closeHelp() {
  if (ui.helpModal) ui.helpModal.classList.remove('is-open');
  Sound.play('click');
}

function bindUI() {
  ui.btnStart.addEventListener('click', () => { Sound.play('ui'); renderHeroCards(); selectHero(App.hero); showScreen('select'); });
  ui.btnBackHome.addEventListener('click', () => { Sound.play('click'); showScreen('home'); });
  ui.btnGo.addEventListener('click', () => { Sound.play('ui'); startBattle(); });
  ui.btnHelpHome.addEventListener('click', openHelp);
  ui.btnHelpPause.addEventListener('click', openHelp);
  ui.btnSoundHome.addEventListener('click', toggleSound);
  if (ui.btnSoundPause) ui.btnSoundPause.addEventListener('click', toggleSound);
  ui.btnPause.addEventListener('click', pauseGame);
  ui.btnResume.addEventListener('click', resumeGame);
  ui.btnRestart.addEventListener('click', () => { Sound.play('ui'); ui.pauseOverlay.classList.remove('is-open'); startBattle(); });
  ui.btnQuit.addEventListener('click', () => { Sound.play('click'); quitToHome(); });
  ui.btnAgain.addEventListener('click', () => { Sound.play('ui'); startBattle(); });
  ui.btnChangeHero.addEventListener('click', () => { Sound.play('click'); renderHeroCards(); selectHero(App.hero); showScreen('select'); });
  ui.btnResultHome.addEventListener('click', () => { Sound.play('click'); showScreen('home'); });
  $$('#difficultyPick .seg').forEach(seg => {
    seg.addEventListener('click', () => {
      App.difficulty = seg.dataset.diff;
      try { localStorage.setItem('ta_diff', App.difficulty); } catch (e) {}
      syncDifficultyUI();
      Sound.play('click');
    });
  });
  $$('[data-close="help"]').forEach(el => el.addEventListener('click', closeHelp));
  document.addEventListener('pointerdown', () => Sound.init(), { once: true });
  window.addEventListener('resize', () => {
    if (App.screen === 'battle') {
      resizeCanvas();
      updateCamera(0, true);
    }
  });
  window.addEventListener('orientationchange', () => setTimeout(() => {
    if (App.screen === 'battle') { resizeCanvas(); updateCamera(0, true); }
  }, 250));
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && App.screen === 'battle' && world && !App.paused && !world.over) pauseGame();
  });
}

/* ============================================================
   主循环 / 测试接口
   ============================================================ */
function loop(now) {
  requestAnimationFrame(loop);
  const dt = Math.min(0.05, Math.max(0.001, (now - lastFrame) / 1000));
  lastFrame = now;
  if (App.screen === 'battle' && world) {
    if (!App.paused) updateWorld(dt);
    renderWorld(now / 1000);
  }
}

function simulateWorld(maxSeconds = 900, opts = {}) {
  const prevWorld = world, prevPlayer = player;
  const w = createWorld(opts.hero || App.hero, opts.difficulty || App.difficulty, true);
  w.headless = true;
  w.countdown = 0;
  w.started = true;
  world = w;
  player = w.heroes.find(h => h.isPlayer);
  const prevSound = Sound.enabled;
  Sound.enabled = false;
  const dt = 1 / 60;
  let elapsed = 0;
  let lastLog = 0;
  while (!w.over && elapsed < maxSeconds) {
    updateWorld(dt);
    elapsed += dt;
    if (Math.floor(elapsed / 60) > lastLog) {
      lastLog = Math.floor(elapsed / 60);
      if (w.time > 0 && w.towerKills.blue + w.towerKills.red === 0 && lastLog === 5) {
        /* 5 分钟仍无塔被推，留作调试信息 */
      }
    }
  }
  const summary = {
    winner: w.winner,
    over: w.over,
    time: +w.time.toFixed(1),
    kills: { ...w.kills },
    towerKills: { ...w.towerKills },
    levels: w.heroes.map(h => ({ team: h.team, hero: h.heroId, level: h.level, kills: h.kills, deaths: h.deaths })),
    baseHp: { blue: Math.max(0, Math.round(w.bases.blue.hp)), red: Math.max(0, Math.round(w.bases.red.hp)) },
    minionsAlive: w.units.filter(u => u.kind === 'minion' && u.alive).length,
    units: w.units.length,
    wave: w.wave
  };
  world = prevWorld;
  player = prevPlayer;
  Sound.enabled = prevSound;
  return summary;
}

function boot() {
  cacheUI();
  battleCanvas = document.getElementById('game');
  ctx = battleCanvas.getContext('2d');
  renderCtxRef = ctx;
  App.render3D = pickRenderer();
  minimapCtx = ui.minimap ? ui.minimap.getContext('2d') : null;
  loadPrefs();
  applySoundState();
  syncDifficultyUI();
  renderHeroCards();
  selectHero(App.hero);
  bindUI();
  bindInput();
  spawnPetals();
  requestAnimationFrame(loop);

  /* 背景延后生成，不挡住首页 */
  setTimeout(() => {
    if (!bgCanvas) bgCanvas = buildBackground();
  }, 120);

  /* URL 参数：?auto=1 直接进战斗（用于自动演示 / 截图） */
  const params = new URLSearchParams(location.search);
  if (params.get('auto') === '1') {
    const hero = params.get('hero');
    if (HERO_ORDER.includes(hero)) App.hero = hero;
    if (params.get('diff') === 'normal') App.difficulty = 'normal';
    setTimeout(() => startBattle({ auto: true }), 450);
  }

  window.__TA = {
    app: App,
    start(opts = {}) { startBattle(opts); },
    skipCountdown() { if (world) { world.countdown = 0; world.started = true; ui.countdown.textContent = ''; } },
    state() {
      if (!world || !player) return { screen: App.screen };
      return {
        screen: App.screen,
        time: +world.time.toFixed(1),
        countdown: +world.countdown.toFixed(2),
        over: world.over,
        winner: world.winner,
        paused: App.paused,
        player: { hero: player.heroId, level: player.level, hp: Math.round(player.hp), maxHp: player.maxHp, kills: player.kills, deaths: player.deaths, x: Math.round(player.x), y: Math.round(player.y), cds: player.cds.map(c => +c.toFixed(1)) },
        kills: { ...world.kills },
        towerKills: { ...world.towerKills },
        towers: { blue: world.towers.blue.map(t => ({ hp: Math.round(t.hp), alive: t.alive, tier: t.tier })), red: world.towers.red.map(t => ({ hp: Math.round(t.hp), alive: t.alive, tier: t.tier })) },
        bases: { blue: Math.round(world.bases.blue.hp), red: Math.round(world.bases.red.hp) },
        units: world.units.length,
        projectiles: world.projectiles.length,
        effects: world.effects.length
      };
    },
    simulate: simulateWorld,
    finish(winner = 'blue') {
      if (!world) return;
      const losingTeam = winner === 'blue' ? 'red' : 'blue';
      const base = world.bases[losingTeam];
      if (base && base.alive) {
        world.towers[losingTeam].forEach(t => { t.alive = false; });
        base.hp = 1;
        killUnit(base, { team: winner, kind: 'hero' });
      }
    },
    onBack() {
      if (App.screen === 'battle') {
        if (!App.paused) pauseGame();
      } else if (App.screen !== 'home') {
        showScreen('home');
      }
    },
    cast(i) { return castSkill(player, i); },
    setPlayerPos(x, y) { if (player) { player.x = x; player.y = y; updateCamera(0, true); } },
    /* 截图调试：把双方英雄摆到桥边，方便检查动作 */
    stage(hold = true) {
      if (!world || !player) return false;
      world.autoPlayer = !hold;
      player.x = 1890; player.y = 720;
      player.level = 3; player.hp = player.maxHp; player.atkTimer = 0.1; player.cds = [0, 0, 0];
      player.invulnT = hold ? 999 : 3;
      const enemies = world.heroes.filter(h => h.team !== player.team);
      const mates = world.heroes.filter(h => h.team === player.team && h !== player);
      const es = [[2070, 670], [2090, 810], [2190, 730]];
      enemies.forEach((h, i) => {
        if (!es[i]) return;
        h.alive = true; h.deathT = 0; h.hp = h.maxHp; h.level = 3;
        h.x = es[i][0]; h.y = es[i][1]; h.stunT = 0; h.atkTimer = 0.5;
        h.invulnT = 0;
        if (hold) { h.cds = [90, 90, 90]; h.speed = 0; }
      });
      mates.forEach((h, i) => {
        h.alive = true; h.deathT = 0; h.hp = h.maxHp; h.level = 3;
        h.x = 1770 - i * 50; h.y = 680 + i * 100; h.stunT = 0;
        if (hold) { h.cds = [90, 90, 90]; h.speed = 0; }
      });
      updateCamera(0, true);
      return true;
    },
    playAnim(kind) {
      if (!player) return;
      if (kind === 'attack') { player.atkAnim = ANIM_DUR.atk(player); player.atkKind = player.range > 160 ? 2 : 1; }
      else if (kind === 'cast') { player.castAnim = ANIM_DUR.cast(player); player.castId = 0; }
      else if (kind === 'hurt') { player.hurtT = ANIM_DUR.hurt(player); player.hitDir = 1; }
      else if (kind === 'spin') { player.spinT = ANIM_DUR.spin(player); }
      else if (kind === 'death') { player.alive = false; player.deathT = ANIM_DUR.death(player) * 0.96; player.respawnT = 999; }
    },
    /* 定格在动作的某个进度上，便于逐帧检查姿势 */
    still(on = true) { App.paused = !!on; return App.paused; },
    pose(kind, p = 0.5) {
      if (!player) return false;
      p = clamp(p, 0, 1);
      player.alive = kind !== 'death';
      player.deathT = kind === 'death' ? ANIM_DUR.death(player) * (1 - p) : 0;
      player.atkAnim = kind === 'attack' ? ANIM_DUR.atk(player) * (1 - p) : 0;
      player.atkKind = player.range > 160 ? 2 : 1;
      player.castAnim = kind === 'cast' ? ANIM_DUR.cast(player) * (1 - p) : 0;
      player.castId = kind === 'cast' ? 0 : -1;
      player.hurtT = kind === 'hurt' ? ANIM_DUR.hurt(player) * (1 - p) : 0;
      player.spinT = kind === 'spin' ? ANIM_DUR.spin(player) * (1 - p) : 0;
      return player.heroId + ':' + kind + ':' + p;
    }
  };
}

document.addEventListener('DOMContentLoaded', boot);
