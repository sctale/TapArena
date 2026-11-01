'use strict';
/* ============================================================
   萌兽峡谷 · 基础数据
   ============================================================ */

const TAU = Math.PI * 2;
const WORLD = { w: 3000, h: 1600 };
const BASE_POS = {
  blue: { x: 330, y: 1010 },
  red:  { x: 2660, y: 1010 }
};

/* 单条主路：从左下森林营地弯到右上水晶花园 */
const LANE = [
  { x: 360, y: 1010 },
  { x: 600, y: 1010 },
  { x: 860, y: 1080 },
  { x: 1120, y: 1085 },
  { x: 1300, y: 960 },
  { x: 1470, y: 878 },
  { x: 1630, y: 888 },
  { x: 1800, y: 1005 },
  { x: 2020, y: 1050 },
  { x: 2260, y: 1015 },
  { x: 2460, y: 975 },
  { x: 2640, y: 1010 }
];

const TOWER_POS = {
  blue: [
    { x: 1150, y: 936,  tier: 0 },
    { x: 790,  y: 1218, tier: 1 }
  ],
  red: [
    { x: 1850, y: 1188, tier: 0 },
    { x: 2230, y: 872,  tier: 1 }
  ]
};

const BUSHES = [
  { x: 985, y: 830, r: 72 },
  { x: 1215, y: 1275, r: 78 },
  { x: 1760, y: 785, r: 70 },
  { x: 1990, y: 1230, r: 76 },
  { x: 610, y: 1245, r: 64 },
  { x: 2420, y: 790, r: 62 }
];

const HONEY_SPOTS = [
  { x: 1235, y: 445 },
  { x: 1775, y: 1245 }
];

const XP_TABLE = [0, 130, 340, 630, 980, 1400]; // 升到 lvl+1 所需的累计经验
const MAX_LEVEL = 6;

const HERO_DEFS = {
  tiger: {
    id: 'tiger', name: '阿虎', title: '勇气小虎', role: '战士', roleShort: '战士',
    tagline: '冲在最前面，替小伙伴挡住危险！',
    difficulty: 1, ribbon: '最好上手', img: 'assets/tiger.jpg',
    hp: 1080, damage: 54, range: 100, atkInterval: 0.72, speed: 272,
    radius: 32, growthHp: 122, growthDmg: 6.2,
    fur: '#f7a94f', furDark: '#c9752f', cream: '#fff2da', accent: '#2f9c8f',
    skillColors: [['#ffd27f', '#ef7d3f'], ['#ffe08a', '#e6a23c'], ['#ffdfa0', '#e7782f']],
    skills: [
      { name: '猛虎冲撞', icon: 'dash', cd: 6.5, desc: '向前冲撞，撞飞路上的敌人' },
      { name: '勇气咆哮', icon: 'roar', cd: 9.5, desc: '震伤周围敌人，并获得厚厚护盾' },
      { name: '旋风爪', icon: 'spin', cd: 24, ult: true, desc: '旋转爪击，把周围敌人转晕' }
    ]
  },
  fox: {
    id: 'fox', name: '灵灵', title: '星光小狐', role: '法师', roleShort: '法师',
    tagline: '躲在后面放星光，一颗火球好厉害！',
    difficulty: 2, img: 'assets/fox.jpg',
    hp: 820, damage: 46, range: 300, atkInterval: 0.85, speed: 268,
    radius: 28, growthHp: 82, growthDmg: 7.2,
    fur: '#f8cd92', furDark: '#d18b49', cream: '#fff7e6', accent: '#7d5cd6',
    skillColors: [['#ffcf8a', '#f17b3a'], ['#c9b6ff', '#7a5bd4'], ['#bdaaff', '#5e3fbf']],
    skills: [
      { name: '星光火球', icon: 'fire', cd: 5.5, desc: '丢出大火球，炸伤一片敌人' },
      { name: '瞬闪星步', icon: 'blink', cd: 10, desc: '向摇杆方向闪现，落地迸出星光' },
      { name: '流星雨', icon: 'meteor', cd: 26, ult: true, desc: '召唤三颗流星，砸向敌人最密的地方' }
    ]
  },
  rabbit: {
    id: 'rabbit', name: '朵朵', title: '星光小兔', role: '辅助射手', roleShort: '辅助',
    tagline: '会治疗的小伙伴，和大家一起闪闪发光！',
    difficulty: 1, img: 'assets/rabbit.jpg',
    hp: 900, damage: 42, range: 280, atkInterval: 0.8, speed: 262,
    radius: 28, growthHp: 96, growthDmg: 5.4,
    fur: '#fff7f3', furDark: '#f0c2cc', cream: '#ffe9ee', accent: '#f27ea8',
    skillColors: [['#ffd0dc', '#ef7fa9'], ['#b7f0cf', '#3fae7a'], ['#ffe6a0', '#ef9a3c']],
    skills: [
      { name: '胡萝卜星镖', icon: 'dart', cd: 4.5, desc: '丢出会穿透的星镖，让敌人慢下来' },
      { name: '治愈微光', icon: 'heal', cd: 12, desc: '治疗自己和附近队友，还加一点速度' },
      { name: '满月祝福', icon: 'moon', cd: 26, ult: true, desc: '给全队护盾和治疗，月光震慑周围敌人' }
    ]
  },
  bear: {
    id: 'bear', name: '阿岳', title: '森林大熊', role: '坦克', roleShort: '坦克',
    tagline: '站在最前面挡住敌人，保护小伙伴！',
    difficulty: 1, ribbon: '最抗打', img: 'assets/bear.jpg',
    hp: 1420, damage: 48, range: 96, atkInterval: 0.9, speed: 232,
    radius: 36, growthHp: 152, growthDmg: 5.4,
    fur: '#b98155', furDark: '#8d5c39', cream: '#ffe9cf', accent: '#5a8f5f',
    skillColors: [['#cfe9b4', '#5f9a52'], ['#ffe0b0', '#c98a3f'], ['#bfe3c8', '#3f7d55']],
    skills: [
      { name: '荷叶拍击', icon: 'bash', cd: 6, desc: '用荷叶盾往前一拍，把敌人推开并减速' },
      { name: '熊抱一下', icon: 'hug', cd: 11, desc: '抱住最近的敌人拉到自己身边，抱得头晕' },
      { name: '山崩地裂', icon: 'quake', cd: 28, ult: true, desc: '跳起砸地，大范围震晕敌人并留下减速裂谷' }
    ]
  },
  otter: {
    id: 'otter', name: '泡泡', title: '溪水水獭', role: '控制法师', roleShort: '控制',
    tagline: '滑来滑去丢水泡，让敌人走不动路！',
    difficulty: 2, img: 'assets/otter.jpg',
    hp: 900, damage: 40, range: 250, atkInterval: 0.82, speed: 286,
    radius: 28, growthHp: 92, growthDmg: 5.6,
    fur: '#7f9fc4', furDark: '#5b7ba0', cream: '#f4faff', accent: '#3fb5c9',
    skillColors: [['#bfe9ff', '#3fa8c9'], ['#d7f3ff', '#5ac0d8'], ['#a8e6ff', '#2f8fb5']],
    skills: [
      { name: '大水泡', icon: 'bubble', cd: 5, desc: '丢出一颗大水泡，炸开一片水花减速' },
      { name: '滑水冲刺', icon: 'slide', cd: 9.5, desc: '贴地滑一段，留下一条湿滑水道' },
      { name: '瀑布冲击', icon: 'waterfall', cd: 26, ult: true, desc: '召来一道瀑布，把敌人冲进下游' }
    ]
  },
  hedgehog: {
    id: 'hedgehog', name: '尖尖', title: '星星刺猬', role: '远程射手', roleShort: '射手',
    tagline: '离得远远的，一背星星刺唻唻唻！',
    difficulty: 3, ribbon: '要会走位', img: 'assets/hedgehog.jpg',
    hp: 800, damage: 52, range: 320, atkInterval: 0.95, speed: 252,
    radius: 27, growthHp: 78, growthDmg: 7,
    fur: '#c9b18f', furDark: '#8a6f52', cream: '#fff1dd', accent: '#e0685f',
    skillColors: [['#ffd9a8', '#e07a4f'], ['#ffc9c4', '#cf5a55'], ['#ffe6b0', '#e0685f']],
    skills: [
      { name: '三连尖刺', icon: 'spikes', cd: 5.5, desc: '一次射出三根尖刺，扇形覆盖前方' },
      { name: '缩成刺球', icon: 'curl', cd: 11, desc: '缩成球挡住攻击，打你的敌人会被扎到' },
      { name: '万刺齐发', icon: 'burst', cd: 27, ult: true, desc: '全身尖刺向四周炸开，近距离最痛' }
    ]
  }
};
const HERO_ORDER = ['tiger', 'fox', 'rabbit', 'bear', 'otter', 'hedgehog'];

/* ---------- 技能图标（内联 SVG，避免任何外部依赖） ---------- */
const SKILL_ICONS = {
  dash: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6 26L18 14"/><path d="M13 8h11v11"/><path d="M5 17h6M4 11h6" opacity=".55"/></svg>',
  roar: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="13" cy="16" r="2.6" fill="currentColor" stroke="none"/><path d="M18 9a9 9 0 0 1 0 14"/><path d="M22 6a14 14 0 0 1 0 20" opacity=".65"/><path d="M5 12c-2 2.4-2 5.6 0 8" opacity=".55"/></svg>',
  spin: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M16 4a12 12 0 0 1 12 12"/><path d="M28 20a12 12 0 0 1-12 8"/><path d="M12 24A12 12 0 0 1 4 12" opacity=".8"/><path d="M8 8a11 11 0 0 1 6-3" opacity=".45"/><path d="M12 12l8 8M20 12l-8 8" opacity=".9"/></svg>',
  fire: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M16 4c1.5 5 8 7 8 14a8 8 0 0 1-16 0c0-4.5 3.4-6.6 4.6-10 1.2 2.6 2 4 3 5 .8-3 .4-6 .4-9z"/><path d="M13 20a3.4 3.4 0 0 0 6 2" opacity=".7"/></svg>',
  blink: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M5 27l8-8M17 15l9-9"/><path d="M18 6h8v8"/><path d="M6 12l3 1M11 6l1 3" opacity=".6"/><path d="M4 20l4 1M20 27l1-4" opacity=".6"/></svg>',
  meteor: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M20 12l-6 6-7 9" opacity=".55"/><path d="M22 4l1.6 4.4L28 10l-4.4 1.6L22 16l-1.6-4.4L16 10l4.4-1.6z" fill="currentColor" stroke="none"/><path d="M8 8l1 2.6L11.6 12 9 13l-1 2.6L7 13l-2.6-1L7 10.6z" fill="currentColor" stroke="none" opacity=".7"/></svg>',
  dart: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M9 22c6-1 11-5 14-13"/><path d="M20 6l5 1 1 5" /><path d="M9 22l-1 5 5-2" opacity=".8"/><path d="M5 10l3 2M12 5l2 3" opacity=".55"/></svg>',
  heal: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M16 26S5 19.6 5 12.6C5 9 7.8 6.4 11.2 6.4c2.2 0 4 1.2 4.8 2.6.8-1.4 2.6-2.6 4.8-2.6 3.4 0 6.2 2.6 6.2 6.2C27 19.6 16 26 16 26z"/><path d="M16 12v8M12 16h8" opacity=".95"/></svg>',
  moon: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M21 5a11 11 0 1 0 6 20A12 12 0 0 1 21 5z"/><path d="M6 8l1 2.4L9.4 11 7 12l-1 2.4L5 12l-2.4-1L5 10.4z" fill="currentColor" stroke="none" opacity=".8"/><path d="M24 24l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z" fill="currentColor" stroke="none" opacity=".65"/></svg>',
  bash: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M17 6c6 1.5 9 5.5 9 10s-3 8.5-9 10c-3-4-3-16 0-20z"/><path d="M17 6c-4 1.5-6 5.5-6 10s2 8.5 6 10" opacity=".55"/><path d="M4 12l4 4-4 4" opacity=".8"/></svg>',
  hug: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M7 11c-3 3-3 8 0 11 2 2 5 2 6 0"/><path d="M25 11c3 3 3 8 0 11-2 2-5 2-6 0"/><circle cx="16" cy="11" r="4" opacity=".85"/><path d="M13 22c1.6 1.6 4.4 1.6 6 0" opacity=".7"/></svg>',
  quake: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M4 22h24"/><path d="M11 22l-2 6M21 22l2 6M16 22v7" opacity=".8"/><path d="M16 4l4 7h-8z" fill="currentColor" stroke="none"/><path d="M6 15c3-2 6-2 9 0M17 15c3-2 6-2 9 0" opacity=".5"/></svg>',
  bubble: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="17" cy="17" r="9"/><path d="M13 12a5 5 0 0 0-2 4" opacity=".9"/><circle cx="7" cy="8" r="2.6" opacity=".7"/><circle cx="25" cy="6" r="1.8" opacity=".5"/></svg>',
  slide: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M4 24c5 0 6-4 11-4s7 4 12 4"/><path d="M12 15c2-4 6-6 11-6"/><path d="M20 5l4 4-4 4" opacity=".85"/></svg>',
  waterfall: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M7 5c0 8-2 12-2 17M16 5c0 9-1 13-1 18M25 5c0 8 1 12 1 17" opacity=".9"/><path d="M4 26c4-2 8 2 12 0s8-2 12 0"/></svg>',
  spikes: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><path d="M5 16h8M6 9l7 4M6 23l7-4"/><path d="M18 6l9 10-9 10" opacity=".9"/></svg>',
  curl: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="16" cy="16" r="7"/><path d="M16 3v4M16 25v4M3 16h4M25 16h4M7 7l3 3M22 22l3 3M25 7l-3 3M10 22l-3 3" opacity=".9"/></svg>',
  burst: '<svg viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="16" cy="16" r="4" fill="currentColor" stroke="none"/><path d="M16 3v5M16 24v5M3 16h5M24 16h5M7 7l3.5 3.5M21.5 21.5L25 25M25 7l-3.5 3.5M10.5 21.5L7 25"/></svg>'
};

function skillIcon(name) { return SKILL_ICONS[name] || SKILL_ICONS.dash; }
function heroIconHTML(index) { return skillIcon(HERO_DEFS[index].skills[2].icon); }

/* ============================================================
   小音效合成器：无音频文件、可离线
   ============================================================ */
const Sound = {
  ctx: null,
  enabled: true,
  _last: {},
  init() {
    if (this.ctx) {
      if (this.ctx.state === 'suspended') this.ctx.resume().catch(() => {});
      return;
    }
    try {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (AC) this.ctx = new AC();
    } catch (e) { /* 静音环境 */ }
  },
  tick(name, gap) {
    const now = performance.now();
    if (this._last[name] && now - this._last[name] < gap) return false;
    this._last[name] = now;
    return true;
  },
  tone(freq, dur, opt = {}) {
    if (!this.enabled || !this.ctx) return;
    const t0 = this.ctx.currentTime + (opt.delay || 0);
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = opt.type || 'sine';
    osc.frequency.setValueAtTime(freq, t0);
    if (opt.to) osc.frequency.exponentialRampToValueAtTime(Math.max(40, opt.to), t0 + dur);
    const vol = opt.vol == null ? 0.045 : opt.vol;
    const attack = opt.attack == null ? 0.008 : opt.attack;
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(vol, t0 + attack);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(gain);
    gain.connect(this.ctx.destination);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  },
  play(name) {
    if (!this.enabled) return;
    this.init();
    if (!this.ctx) return;
    switch (name) {
      case 'ui':
        this.tone(620, 0.09, { to: 760, type: 'triangle', vol: 0.035 });
        break;
      case 'click':
        this.tone(520, 0.06, { type: 'triangle', vol: 0.03 });
        break;
      case 'nope':
        if (!this.tick('nope', 220)) return;
        this.tone(240, 0.12, { to: 190, type: 'triangle', vol: 0.032 });
        break;
      case 'hit':
        if (!this.tick('hit', 55)) return;
        this.tone(180, 0.07, { to: 90, type: 'triangle', vol: 0.028 });
        this.tone(420, 0.05, { to: 200, type: 'sine', vol: 0.014 });
        break;
      case 'shoot':
        if (!this.tick('shoot', 80)) return;
        this.tone(660, 0.09, { to: 330, type: 'sine', vol: 0.022 });
        break;
      case 'skill':
        this.tone(520, 0.16, { to: 880, type: 'triangle', vol: 0.04 });
        this.tone(780, 0.2, { type: 'sine', vol: 0.02, delay: 0.05 });
        break;
      case 'ult':
        this.tone(392, 0.28, { type: 'triangle', vol: 0.045 });
        this.tone(523, 0.3, { type: 'triangle', vol: 0.04, delay: 0.08 });
        this.tone(784, 0.42, { type: 'sine', vol: 0.04, delay: 0.16 });
        break;
      case 'heal':
        this.tone(660, 0.22, { to: 990, type: 'sine', vol: 0.038 });
        this.tone(880, 0.3, { type: 'sine', vol: 0.028, delay: 0.1 });
        break;
      case 'kill':
        this.tone(523, 0.12, { type: 'triangle', vol: 0.04 });
        this.tone(659, 0.14, { type: 'triangle', vol: 0.04, delay: 0.09 });
        this.tone(1046, 0.3, { type: 'sine', vol: 0.035, delay: 0.18 });
        break;
      case 'die':
        this.tone(330, 0.3, { to: 160, type: 'triangle', vol: 0.035 });
        break;
      case 'tower':
        this.tone(150, 0.5, { to: 55, type: 'triangle', vol: 0.06 });
        this.tone(300, 0.3, { to: 120, type: 'sine', vol: 0.03 });
        break;
      case 'level':
        this.tone(659, 0.16, { type: 'triangle', vol: 0.04 });
        this.tone(880, 0.24, { type: 'triangle', vol: 0.04, delay: 0.1 });
        break;
      case 'collect':
        this.tone(880, 0.1, { type: 'sine', vol: 0.035 });
        this.tone(1320, 0.18, { type: 'sine', vol: 0.03, delay: 0.07 });
        break;
      case 'win':
        [523, 659, 784, 1046].forEach((f, i) => this.tone(f, 0.42, { type: 'triangle', vol: 0.045, delay: i * 0.16 }));
        break;
      case 'lose':
        [392, 330, 262].forEach((f, i) => this.tone(f, 0.5, { type: 'sine', vol: 0.04, delay: i * 0.2 }));
        break;
      case 'count':
        this.tone(660, 0.12, { type: 'triangle', vol: 0.035 });
        break;
      case 'go':
        this.tone(880, 0.3, { to: 1174, type: 'triangle', vol: 0.05 });
        break;
    }
  }
};

/* ============================================================
   小工具
   ============================================================ */
const clamp = (v, a, b) => v < a ? a : (v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const rand = (a = 1, b = 0) => b + Math.random() * (a - b);
const randInt = (a, b) => Math.floor(a + Math.random() * (b - a + 1));
const pickOne = arr => arr[Math.floor(Math.random() * arr.length)];
const dist = (ax, ay, bx, by) => Math.hypot(ax - bx, ay - by);
function norm(x, y) {
  const d = Math.hypot(x, y) || 1;
  return { x: x / d, y: y / d };
}
function fmtTime(s) {
  s = Math.max(0, Math.floor(s));
  return String(Math.floor(s / 60)).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0');
}
function teamColor(team) { return team === 'blue' ? '#49cfdd' : '#ff8b78'; }
function teamDark(team) { return team === 'blue' ? '#227f83' : '#b64a3f'; }
function enemyOf(team) { return team === 'blue' ? 'red' : 'blue'; }

function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
