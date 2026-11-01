/* ============================================================
   anim.js —— 关键帧动画系统
   ------------------------------------------------------------
   所有角色动作都由这里的 clip 数据驱动，渲染层（Phaser 帧图集 /
   旧版 Canvas 直绘）只负责"把 pose 画出来"，不再自己算曲线。

   pose 通道：
     atk / cast / hurt / spin / dying   动作强度（-1..1，负值=蓄力后仰）
     phase / walkSin                    步态周期
     bob / legSwing                     身体起伏与腿摆动
     rootLunge / rootLean / rootLift    根骨骼位移（前冲、倾斜、离地）
     squashY                            挤压拉伸（squashX 自动取倒数）
     alpha                              淡出（死亡用）
   ============================================================ */

const EASE = {
  linear: t => t,
  quadIn: t => t * t,
  quadOut: t => 1 - (1 - t) * (1 - t),
  quadInOut: t => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2),
  cubicOut: t => 1 - Math.pow(1 - t, 3),
  expoOut: t => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t)),
  backOut: t => {
    const c1 = 1.70158, c3 = c1 + 1;
    return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
  },
  sineIn: t => 1 - Math.cos((t * Math.PI) / 2),
  sineOut: t => Math.sin((t * Math.PI) / 2),
  sineInOut: t => -(Math.cos(Math.PI * t) - 1) / 2,
  /* 顿帧感：几乎不动，然后瞬间弹开 */
  holdSnap: t => (t < 0.62 ? t * 0.12 : 0.074 + (t - 0.62) * 2.44)
};

function sampleTrack(keys, t) {
  if (!keys || !keys.length) return 0;
  if (t <= keys[0].t) return keys[0].v;
  for (let i = 1; i < keys.length; i++) {
    const a = keys[i - 1], b = keys[i];
    if (t <= b.t) {
      const span = b.t - a.t;
      const k = span <= 0 ? 1 : (t - a.t) / span;
      const e = (EASE[b.e] || EASE.linear)(k);
      return a.v + (b.v - a.v) * e;
    }
  }
  return keys[keys.length - 1].v;
}

function sampleClip(clip, tNorm) {
  const out = {};
  const ch = clip.ch || {};
  for (const name in ch) out[name] = sampleTrack(ch[name], tNorm);
  return out;
}

/* 通用 clip：三位英雄共用同一套时间轴，角色差异写在各自 override 里 */
const BASE_CLIPS = {
  idle: {
    dur: 1.6, loop: true,
    ch: {
      bob: [ {t:0, v:-1, e:'sineInOut'}, {t:0.5, v:1, e:'sineInOut'}, {t:1, v:-1} ]
    }
  },
  walk: {
    dur: 0.52, loop: true,
    ch: {
      phase: [ {t:0, v:0}, {t:1, v:1} ],
      bob: [ {t:0, v:0, e:'sineIn'}, {t:0.25, v:-1, e:'sineOut'}, {t:0.5, v:0, e:'sineIn'}, {t:0.75, v:-1, e:'sineOut'}, {t:1, v:0} ],
      legSwing: [ {t:0, v:0, e:'sineInOut'}, {t:0.25, v:1, e:'sineInOut'}, {t:0.5, v:0, e:'sineInOut'}, {t:0.75, v:-1, e:'sineInOut'}, {t:1, v:0} ]
    }
  },
  /* 普攻：0-28% 蓄力后坐，28-46% 爆发挥出，46-58% 命中停顿，之后收势 */
  attack: {
    dur: 0.26,
    ch: {
      atk: [ {t:0, v:0, e:'quadOut'}, {t:0.28, v:-0.42, e:'expoOut'}, {t:0.46, v:1, e:'holdSnap'}, {t:0.62, v:0.86}, {t:1, v:0, e:'quadOut'} ],
      rootLunge: [ {t:0, v:0, e:'quadIn'}, {t:0.28, v:-0.16, e:'expoOut'}, {t:0.46, v:1, e:'quadOut'}, {t:0.72, v:0.55}, {t:1, v:0} ],
      rootLean: [ {t:0, v:0, e:'quadIn'}, {t:0.28, v:-0.3, e:'expoOut'}, {t:0.48, v:1, e:'quadOut'}, {t:1, v:0} ],
      squashY: [ {t:0, v:0, e:'quadOut'}, {t:0.28, v:-0.35, e:'expoOut'}, {t:0.46, v:1, e:'quadOut'}, {t:1, v:0} ],
      bob: [ {t:0, v:0}, {t:0.46, v:0.3, e:'quadOut'}, {t:1, v:0} ]
    }
  },
  /* 施法：抬手聚能（慢），释放（快），回落 */
  cast: {
    dur: 0.46,
    ch: {
      cast: [ {t:0, v:0, e:'quadIn'}, {t:0.42, v:1, e:'cubicOut'}, {t:0.62, v:1}, {t:1, v:0, e:'quadOut'} ],
      rootLift: [ {t:0, v:0, e:'quadIn'}, {t:0.42, v:1, e:'cubicOut'}, {t:0.66, v:0.7}, {t:1, v:0} ],
      squashY: [ {t:0, v:0, e:'quadOut'}, {t:0.3, v:-0.5, e:'expoOut'}, {t:0.55, v:1, e:'quadOut'}, {t:1, v:0} ],
      bob: [ {t:0, v:0}, {t:0.5, v:1, e:'sineInOut'}, {t:1, v:0} ]
    }
  },
  /* 受击：瞬间后仰 + 压扁，快速恢复 */
  hurt: {
    dur: 0.24,
    ch: {
      hurt: [ {t:0, v:0, e:'expoOut'}, {t:0.16, v:1, e:'quadOut'}, {t:1, v:0, e:'quadOut'} ],
      rootLean: [ {t:0, v:0, e:'expoOut'}, {t:0.18, v:-1, e:'quadOut'}, {t:0.6, v:-0.25}, {t:1, v:0} ],
      rootLunge: [ {t:0, v:0, e:'expoOut'}, {t:0.18, v:-1, e:'quadOut'}, {t:1, v:0} ],
      squashY: [ {t:0, v:0, e:'expoOut'}, {t:0.16, v:-1, e:'quadOut'}, {t:0.5, v:0.3}, {t:1, v:0} ]
    }
  },
  /* 大招旋转：持续整圈，带轻微上浮 */
  spin: {
    dur: 1,
    ch: {
      spin: [ {t:0, v:0}, {t:1, v:1} ],
      bob: [ {t:0, v:0}, {t:0.5, v:1, e:'sineInOut'}, {t:1, v:0} ]
    }
  },
  /* 阵亡：先向后弹起、旋转倒下、淡出 */
  death: {
    dur: 1.15,
    ch: {
      dying: [ {t:0, v:0}, {t:1, v:1} ],
      rootLean: [ {t:0, v:0, e:'expoOut'}, {t:0.3, v:-0.7, e:'quadOut'}, {t:1, v:-1} ],
      rootLift: [ {t:0, v:0, e:'quadOut'}, {t:0.22, v:1, e:'quadOut'}, {t:0.7, v:0.2}, {t:1, v:0} ],
      squashY: [ {t:0, v:0, e:'expoOut'}, {t:0.18, v:-1, e:'quadOut'}, {t:0.6, v:0.4}, {t:1, v:-0.5} ],
      alpha: [ {t:0, v:1}, {t:0.55, v:1}, {t:1, v:0} ]
    }
  }
};

/* 角色差异：重量感与幅度。阿虎最猛、灵灵偏飘、朵朵最轻 */
const HERO_ANIM = {
  tiger: {
    scale: { attack: { lunge: 18, lean: 0.2, squash: 0.09 }, cast: { lift: 8 }, hurt: { lean: 0.16, lunge: 6, squash: 0.06 } },
    clips: {
      attack: { dur: 0.27 },
      cast: { dur: 0.48 }
    }
  },
  fox: {
    scale: { attack: { lunge: 9, lean: 0.11, squash: 0.06 }, cast: { lift: 10 }, hurt: { lean: 0.12, lunge: 5, squash: 0.05 } },
    clips: {
      attack: { dur: 0.24 },
      cast: { dur: 0.44 },
      idle: { dur: 1.9 }
    }
  },
  rabbit: {
    scale: { attack: { lunge: 8, lean: 0.09, squash: 0.05 }, cast: { lift: 11 }, hurt: { lean: 0.13, lunge: 5, squash: 0.05 } },
    clips: {
      attack: { dur: 0.22 },
      cast: { dur: 0.42 },
      walk: { dur: 0.44 },
      idle: { dur: 1.45 }
    }
  },
  /* 棕熊：最重，出手慢但位移大、压得最扁 */
  bear: {
    scale: { attack: { lunge: 21, lean: 0.17, squash: 0.13 }, cast: { lift: 5 }, hurt: { lean: 0.09, lunge: 3.5, squash: 0.05 } },
    clips: {
      attack: { dur: 0.34 },
      cast: { dur: 0.52 },
      walk: { dur: 0.66 },
      idle: { dur: 2.1 },
      hurt: { dur: 0.2 }
    }
  },
  /* 水獭：最轻快，动作小但频率高 */
  otter: {
    scale: { attack: { lunge: 9, lean: 0.1, squash: 0.05 }, cast: { lift: 10 }, hurt: { lean: 0.14, lunge: 6, squash: 0.05 } },
    clips: {
      attack: { dur: 0.22 },
      cast: { dur: 0.4 },
      walk: { dur: 0.4 },
      idle: { dur: 1.4 }
    }
  },
  /* 刺猬：出手是"向后一缩再弹出去"，所以前冲小、压扁大 */
  hedgehog: {
    scale: { attack: { lunge: 5, lean: 0.07, squash: 0.1 }, cast: { lift: 9 }, hurt: { lean: 0.15, lunge: 6, squash: 0.06 } },
    clips: {
      attack: { dur: 0.26 },
      cast: { dur: 0.44 },
      walk: { dur: 0.46 },
      idle: { dur: 1.5 }
    }
  }
};

function getClip(heroId, name) {
  const base = BASE_CLIPS[name];
  if (!base) return null;
  const over = (HERO_ANIM[heroId] && HERO_ANIM[heroId].clips && HERO_ANIM[heroId].clips[name]) || {};
  return { dur: over.dur || base.dur, loop: over.loop != null ? over.loop : base.loop, ch: base.ch };
}

function heroScale(heroId) {
  return (HERO_ANIM[heroId] && HERO_ANIM[heroId].scale) || {
    attack: { lunge: 10, lean: 0.1, squash: 0.06 },
    cast: { lift: 8 },
    hurt: { lean: 0.12, lunge: 5, squash: 0.05 }
  };
}

/* 动作时长常量（game.js 与烘焙器共用，避免两处硬编码） */
const ANIM_DUR = {
  atk: h => getClip(h.heroId, 'attack').dur,
  cast: h => getClip(h.heroId, 'cast').dur,
  hurt: h => getClip(h.heroId, 'hurt').dur,
  spin: h => getClip(h.heroId, 'spin').dur,
  death: h => getClip(h.heroId, 'death').dur
};

const ZERO_POSE = {
  atk: 0, cast: 0, hurt: 0, spin: 0, dying: 0,
  phase: 0, walkSin: 0, bob: 0, legSwing: 0,
  rootLunge: 0, rootLean: 0, rootLift: 0, squashY: 0, alpha: 1
};

function mixPose(target, add, weight) {
  for (const k in add) {
    if (typeof add[k] !== 'number') continue;
    target[k] = (target[k] || 0) + add[k] * weight;
  }
  return target;
}

/* 动作优先级：死 > 大招 > 施法 > 普攻 > 受击 > 走 > 待机 */
function activeClip(unit, vt) {
  if (!unit.alive) {
    const d = getClip(unit.heroId, 'death').dur;
    return { name: 'death', t: clamp(1 - (unit.deathT || 0) / d, 0, 1) };
  }
  if (unit.spinT > 0) return { name: 'spin', t: clamp(1 - unit.spinT / getClip(unit.heroId, 'spin').dur, 0, 1) };
  if (unit.castAnim > 0) return { name: 'cast', t: clamp(1 - unit.castAnim / getClip(unit.heroId, 'cast').dur, 0, 1) };
  if (unit.atkAnim > 0) return { name: 'attack', t: clamp(1 - unit.atkAnim / getClip(unit.heroId, 'attack').dur, 0, 1) };
  if (unit.hurtT > 0) return { name: 'hurt', t: clamp(1 - unit.hurtT / getClip(unit.heroId, 'hurt').dur, 0, 1) };
  if (unit.walkT > 0) return { name: 'walk', t: (unit.walkT / getClip(unit.heroId, 'walk').dur) % 1 };
  return { name: 'idle', t: ((vt || 0) / getClip(unit.heroId, 'idle').dur + (unit.seed || 0) * 0.37) % 1 };
}

/* 通道 → 渲染字段的统一换算。face = ±1，hitDir = 来击方向（世界 x） */
function resolvePose(pose, heroId, face, hitDir) {
  const s = heroScale(heroId);
  const clip = pose.clip;
  const moving = !!pose.isMoving;

  pose.walkSin = moving ? Math.sin(pose.phase * Math.PI * 2) : 0;
  pose.legSwing = moving ? pose.walkSin * 5.5 : 0;
  if (moving) pose.bob = Math.abs(pose.walkSin) * 2.8;

  const lungeScale = clip === 'hurt' ? s.hurt.lunge : clip === 'attack' ? s.attack.lunge : 0;
  pose.lunge = (pose.rootLunge || 0) * lungeScale * (clip === 'hurt' ? (hitDir || 1) : 1);

  const leanScale = clip === 'hurt' ? s.hurt.lean : clip === 'attack' ? s.attack.lean : clip === 'death' ? 0.5 : 0.1;
  const leanWorld = (pose.rootLean || 0) * leanScale * (clip === 'hurt' ? (hitDir || 1) : 1);
  pose.lean = leanWorld * (face >= 0 ? 1 : -1);

  pose.lift = (pose.rootLift || 0) * s.cast.lift;
  const squashScale = clip === 'hurt' ? s.hurt.squash : clip === 'attack' ? s.attack.squash : clip === 'death' ? 0.08 : 0.05;
  pose.squashY = 1 + (pose.squashY || 0) * squashScale;
  pose.squashX = 1 / pose.squashY;

  pose.spinRaw = clip === 'spin' ? pose.spin : 0;
  pose.dying = clip === 'death' ? 1 : 0;
  pose.deathP = clip === 'death' ? pose.dying : 0;
  pose.atk = clip === 'attack' ? pose.atk : 0;
  pose.cast = clip === 'cast' ? pose.cast : 0;
  pose.hurt = clip === 'hurt' ? pose.hurt : 0;
  pose.moving = moving;
  if (pose.alpha == null) pose.alpha = 1;
  return pose;
}

/* 生成渲染层需要的 pose 对象。vt 为"虚拟时间"，用于烘焙时保持微动一致 */
function buildPose(unit, vt) {
  const act = activeClip(unit, vt);
  const clip = getClip(unit.heroId, act.name);
  const pose = Object.assign({}, ZERO_POSE, sampleClip(clip, act.t));
  pose.clip = act.name;
  pose.clipT = act.t;
  pose.isMoving = unit.walkT > 0 && unit.alive && act.name !== 'attack' && act.name !== 'cast';
  if (act.name === 'idle') pose.bob = (pose.bob || 0) * 1.3;
  pose.time = vt;
  return resolvePose(pose, unit.heroId, unit.facing >= 0 ? 1 : -1, unit.hitDir || 1);
}

/* 供烘焙器使用：直接按 clip 名 + 归一化时间取 pose，不依赖单位状态 */
function poseForClip(heroId, clipName, t, opts) {
  opts = opts || {};
  const clip = getClip(heroId, clipName);
  const pose = Object.assign({}, ZERO_POSE, sampleClip(clip, t));
  pose.clip = clipName;
  pose.clipT = t;
  pose.isMoving = clipName === 'walk';
  pose.time = opts.time == null ? t * (clip.dur || 1) : opts.time;
  return resolvePose(pose, heroId, 1, opts.hitDir || 1);
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { EASE, getClip, poseForClip, activeClip, buildPose, BASE_CLIPS, HERO_ANIM, ANIM_DUR };
}
