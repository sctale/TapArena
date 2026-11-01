/* ============================================================
   world3d.js —— Three.js 立体战场渲染层
   ------------------------------------------------------------
   职责：读 game.js 的权威世界状态（world / heroes / minions /
   towers / projectiles / effects），把它变成真 3D 画面。
   逻辑仍然只在 game.js 里，这一层不碰任何玩法数值。

   与 2D 层的分工：
     · 3D canvas：地形、道具、角色、弹道、特效、阴影
     · 2D canvas（#game）：名字、血条、伤害数字、摇杆、小地图、屏幕光影
       —— 文字留在 2D 是为了在任何 DPR 下都清晰，不糊成一片。

   坐标映射：游戏 (x, y) → 3D (x, 0, y)，向上是 +Y。角色默认朝 +X。
   ============================================================ */

/* 角色在世界单位下的体型：2D 版里英雄约占视野高度 9%，
   骨架建模按 34–52 单位给，这里统一放大到接近原来的视觉占比。 */
const HERO_SCALE_3D = 2.35;
const MINION_SCALE_3D = 1.7;

const W3D = {
  ok: false,
  error: null,
  renderer: null, scene: null, camera: null, sun: null,
  heroRigs: new Map(),      // uid -> rig
  rigWarned: {},
  minionPool: [], towerMeshes: [], propMeshes: [],
  ground: null, groundTex: null,
  occluders: [],            // 比主角更靠近镜头时自动淡出的立体道具
  rings: [], shots: [],
  camTarget: { x: 1500, y: 800 },
  camShake: 0, camPunch: 0,
  view: { w: 0, h: 0 },
  _lastT: 0
};

/* ---------- 小工具 ---------- */
function w3dLerp(a, b, t) { return a + (b - a) * t; }
function w3dDamp(cur, target, rate, dt) { return cur + (target - cur) * (1 - Math.exp(-rate * dt)); }
function w3dAngleDamp(cur, target, rate, dt) {
  let d = target - cur;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return cur + d * (1 - Math.exp(-rate * dt));
}

/* 占位骨架：hero-rigs.js 没加载或角色缺失时用它，保证渲染层可独立验证 */
function w3dPlaceholderRig(def, height) {
  const THREE = window.THREE;
  const root = new THREE.Group();
  const mat = new THREE.MeshLambertMaterial({ color: new THREE.Color(def.fur || '#f2a94f') });
  const body = new THREE.Group();
  const torso = new THREE.Mesh(new THREE.SphereGeometry(13, 10, 8), mat);
  torso.scale.set(1, 1.25, 0.9); torso.position.y = height * 0.45;
  const head = new THREE.Group();
  const skull = new THREE.Mesh(new THREE.SphereGeometry(9, 10, 8), mat);
  skull.position.y = height * 0.32;
  head.position.y = height * 0.72;
  head.add(skull);
  const eyes = new THREE.Group();
  const em = new THREE.MeshBasicMaterial({ color: 0x33221a });
  [-3.4, 3.4].forEach(z => {
    const e = new THREE.Mesh(new THREE.SphereGeometry(1.9, 6, 6), em);
    e.position.set(8, height * 0.34, z);
    eyes.add(e);
  });
  const legMat = new THREE.MeshLambertMaterial({ color: new THREE.Color(def.furDark || '#c9752f') });
  const mkLeg = (x, z) => {
    const g = new THREE.Group();
    const m = new THREE.Mesh(new THREE.CylinderGeometry(3.4, 3, 13, 6), legMat);
    m.position.y = -6.5;
    g.add(m); g.position.set(x, height * 0.34, z);
    return g;
  };
  const mkArm = (z) => {
    const g = new THREE.Group();
    const m = new THREE.Mesh(new THREE.CylinderGeometry(3, 2.6, 12, 6), mat);
    m.position.y = -6;
    g.add(m); g.position.set(2, height * 0.62, z);
    return g;
  };
  const tail = new THREE.Group();
  const tm = new THREE.Mesh(new THREE.CylinderGeometry(1.8, 3.6, 16, 6),
    new THREE.MeshLambertMaterial({ color: new THREE.Color(def.cream || '#fff') }));
  tm.position.set(-8, 0, 0); tm.rotation.z = Math.PI / 2.4;
  tail.add(tm); tail.position.set(-11, height * 0.45, 0);

  body.add(torso); body.add(head); body.add(eyes);
  const parts = {
    body, head, eyes, tail, weapon: null, earL: null, earR: null,
    armL: mkArm(-9), armR: mkArm(9),
    legFL: mkLeg(5, -6), legFR: mkLeg(5, 6), legBL: mkLeg(-5, -6), legBR: mkLeg(-5, 6)
  };
  Object.keys(parts).forEach(k => {
    const p = parts[k];
    if (p && p.isObject3D !== undefined && p.traverse) p.traverse(o => { if (o.isMesh) o.castShadow = true; });
  });
  body.traverse(o => { if (o.isMesh) o.castShadow = true; });
  root.add(body);
  return { root, parts, height };
}

/* ---------- 初始化 ---------- */
function w3dInit(host) {
  if (W3D.ok || W3D.error) return W3D.ok;
  const THREE = window.THREE;
  if (!THREE) { W3D.error = 'THREE 未加载'; return false; }
  try {
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'default' });
    const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, coarse ? 1.5 : 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.domElement.id = 'world3d';
    host.appendChild(renderer.domElement);
    W3D.renderer = renderer;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x8fd3a8);
    scene.fog = new THREE.Fog(0x9adbb0, 1500, 3000);
    W3D.scene = scene;

    const camera = new THREE.PerspectiveCamera(46, 1, 20, 4200);
    W3D.camera = camera;

    scene.add(new THREE.HemisphereLight(0xffffff, 0x74a98a, 0.9));
    const sun = new THREE.DirectionalLight(0xfff0c9, 1.05);
    sun.position.set(520, 900, 380);
    sun.castShadow = true;
    const sm = 1024;
    sun.shadow.mapSize.set(sm, sm);
    const sc = sun.shadow.camera;
    sc.left = -760; sc.right = 760; sc.top = 760; sc.bottom = -760; sc.near = 100; sc.far = 2600;
    sun.shadow.bias = -0.0012;
    scene.add(sun);
    scene.add(sun.target);
    W3D.sun = sun;

    /* 地面：用现成的程序化地图当贴图（去掉树，树改成立体道具） */
    const groundCanvas = buildGroundTexture(2048);
    const tex = new THREE.CanvasTexture(groundCanvas);
    tex.colorSpace = THREE.SRGBColorSpace || undefined;
    tex.anisotropy = Math.min(4, renderer.capabilities.getMaxAnisotropy());
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(WORLD.w, WORLD.h, 1, 1),
      new THREE.MeshLambertMaterial({ map: tex })
    );
    ground.rotation.x = -Math.PI / 2;
    ground.position.set(WORLD.w / 2, 0, WORLD.h / 2);
    ground.receiveShadow = true;
    scene.add(ground);
    W3D.ground = ground;
    W3D.groundTex = tex;

    w3dBuildProps();
    W3D.ok = true;
  } catch (e) {
    W3D.error = (e && e.message) || 'init failed';
    console.warn('[W3D] 初始化失败，退回 2D 画面：', W3D.error);
    return false;
  }
  return true;
}

/* 树、灌木、蘑菇灯：真立体道具，位置沿用地图生成结果 */
function w3dBuildProps() {
  const THREE = window.THREE;
  const group = new THREE.Group();
  W3D.scene.add(group);

  const trunkMat = new THREE.MeshLambertMaterial({ color: 0x9c7a52 });
  const leafMats = [0x4f9d6b, 0x5cae77, 0x469060].map(c => new THREE.MeshLambertMaterial({ color: c }));
  const trunkGeo = new THREE.CylinderGeometry(6, 9, 62, 6);
  const crownGeoA = new THREE.SphereGeometry(44, 9, 7);
  const crownGeoB = new THREE.SphereGeometry(31, 9, 7);
  const crownGeoC = new THREE.SphereGeometry(24, 8, 6);

  (MAP_PROPS.trees || []).forEach(t => {
    const g = new THREE.Group();
    const trunk = new THREE.Mesh(trunkGeo, trunkMat);
    trunk.position.y = 31;
    g.add(trunk);
    const mat = leafMats[Math.floor(t.v * leafMats.length) % leafMats.length];
    const crown = new THREE.Mesh(crownGeoA, mat);
    crown.position.y = 86;
    crown.scale.set(1, 0.92 + t.v * 0.25, 1);
    g.add(crown);
    const c2 = new THREE.Mesh(crownGeoB, mat);
    c2.position.set(t.v * 26 - 12, 66, t.v * 18 - 9);
    g.add(c2);
    const c3 = new THREE.Mesh(crownGeoC, mat);
    c3.position.set(-t.v * 24 + 10, 108, t.v * 12 - 6);
    g.add(c3);
    g.position.set(t.x, 0, t.y);
    g.scale.setScalar(t.s);
    g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; o.material = o.material.clone(); } });
    w3dRegisterOccluder(g);
    group.add(g);
  });

  const bushGeo = new THREE.SphereGeometry(26, 8, 6);
  const bushMat = new THREE.MeshLambertMaterial({ color: 0x59a874 });
  (MAP_PROPS.bushes || []).forEach(b => {
    const g = new THREE.Group();
    [[0, 0, 1], [-16, 6, 0.72], [14, -8, 0.8]].forEach(o => {
      const m = new THREE.Mesh(bushGeo, bushMat);
      m.position.set(o[0], 15 * o[2], o[1]);
      m.scale.setScalar(o[2]);
      g.add(m);
    });
    g.position.set(b.x, 0, b.y);
    g.scale.setScalar(0.55 + b.s * 0.35);
    g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; o.material = o.material.clone(); } });
    w3dRegisterOccluder(g);
    group.add(g);
  });

  /* 河边芦苇与石头：给低角度镜头一点前景层次 */
  const reedMat = new THREE.MeshLambertMaterial({ color: 0x7fc08f });
  const reedGeo = new THREE.ConeGeometry(4, 46, 5);
  for (let i = 0; i < 46; i++) {
    const side = i % 2 ? 1 : -1;
    const m = new THREE.Mesh(reedGeo, reedMat);
    m.position.set(1500 + side * (150 + (i % 7) * 26), 22, 120 + i * 32);
    m.rotation.z = side * 0.18;
    m.castShadow = true;
    group.add(m);
  }
  W3D.propMeshes.push(group);
}

/* ---------- 遮挡淡出 ---------- */
/* 注册时把网格列表缓存下来：每帧 traverse + 反复切 transparent 会触发
   着色器重编译，是 3D 模式下最大的一笔开销。 */
function w3dRegisterOccluder(g) {
  const meshes = [];
  g.traverse(o => { if (o.isMesh) meshes.push(o); });
  g.userData.fade = meshes;
  g.userData.fadeOn = null;
  w3dRegisterOccluder(g);
}

function w3dUpdateOccluders(dt) {
  const cam = W3D.camera;
  const focusD = Math.hypot(W3D.camTarget.x - cam.position.x, W3D.camTarget.y - cam.position.z);
  const step = Math.min(0.25, Math.max(0.02, dt * 7));
  for (const g of W3D.occluders) {
    const meshes = g.userData.fade;
    if (!meshes) continue;
    const d = Math.hypot(g.position.x - cam.position.x, g.position.z - cam.position.z);
    const want = d < focusD - 40 ? 0.12 : 1;
    const on = want < 1;
    if (g.userData.fadeOn !== on) {
      g.userData.fadeOn = on;
      for (const o of meshes) {
        o.material.transparent = on;
        o.material.depthWrite = !on;
      }
    }
    for (const o of meshes) {
      const m = o.material;
      m.opacity = m.opacity == null ? 1 : m.opacity + (want - m.opacity) * step;
    }
  }
}
/* ---------- 单位网格 ---------- */
function w3dHeroRig(h) {
  let rig = W3D.heroRigs.get(h.uid);
  if (rig) return rig;
  const THREE = window.THREE;
  const def = HERO_DEFS[h.heroId];
  let built = null;
  try {
    built = (typeof HERO_RIGS !== 'undefined' && HERO_RIGS[h.heroId])
      ? HERO_RIGS[h.heroId](def, THREE) : null;
  } catch (e) {
    /* 单个骨架建模出错绝不能拖垮战场：记一次日志，用占位骨架继续 */
    if (!W3D.rigWarned) { W3D.rigWarned = {}; }
    if (!W3D.rigWarned[h.heroId]) {
      W3D.rigWarned[h.heroId] = true;
      console.warn('[W3D] 骨架 ' + h.heroId + ' 建模失败，暂用占位造型：', e.message);
    }
    built = null;
  }
  rig = built || w3dPlaceholderRig(def, 36);
  rig.height = (rig.height || 36) * HERO_SCALE_3D;
  rig.root.rotation.y = h.facing >= 0 ? 0 : Math.PI;
  W3D.scene.add(rig.root);
  W3D.heroRigs.set(h.uid, rig);
  return rig;
}

function w3dMinionMesh(m) {
  const THREE = window.THREE;
  if (!m.__mesh) {
    const g = new THREE.Group();
    const r = m.big ? 17 : 12;
    const mat = new THREE.MeshLambertMaterial({ color: m.team === 'blue' ? 0x6fd0e6 : 0xf08f7c });
    const body = new THREE.Mesh(new THREE.SphereGeometry(r, 9, 7), mat);
    body.position.y = r * 0.92;
    body.scale.set(1, 1.12, 0.94);
    const sprout = new THREE.Mesh(new THREE.ConeGeometry(3.2, m.big ? 16 : 11, 5),
      new THREE.MeshLambertMaterial({ color: 0x63b877 }));
    sprout.position.y = r * 1.95;
    const eyeMat = new THREE.MeshBasicMaterial({ color: 0x2b1d18 });
    const eyeGeo = new THREE.SphereGeometry(m.big ? 2.6 : 2, 6, 6);
    const eyes = new THREE.Group();
    [-1, 1].forEach(s => {
      const e = new THREE.Mesh(eyeGeo, eyeMat);
      e.position.set(r * 0.78, r * 1.12, s * r * 0.38);
      eyes.add(e);
    });
    g.add(body); g.add(sprout); g.add(eyes);
    g.userData = { body, eyes, sprout, r };
    g.scale.setScalar(MINION_SCALE_3D);
    g.traverse(o => { if (o.isMesh) o.castShadow = true; });
    W3D.scene.add(g);
    m.__mesh = g;
    W3D.minionPool.push(g);
  }
  return m.__mesh;
}

function w3dStructureMesh(u) {
  const THREE = window.THREE;
  if (u.__mesh) return u.__mesh;
  const g = new THREE.Group();
  const isBase = u.kind === 'base';
  const teamCol = u.team === 'blue' ? 0x8fd9ea : 0xf0a291;
  if (isBase) {
    const pad = new THREE.Mesh(new THREE.CylinderGeometry(86, 96, 12, 12),
      new THREE.MeshLambertMaterial({ color: 0xf3e6cf }));
    pad.position.y = 6;
    const crystal = new THREE.Mesh(new THREE.OctahedronGeometry(52, 0),
      new THREE.MeshLambertMaterial({ color: teamCol, transparent: true, opacity: 0.92 }));
    crystal.position.y = 96;
    crystal.scale.set(0.72, 1.5, 0.72);
    g.add(pad); g.add(crystal);
    g.userData = { crystal };
  } else {
    const stem = new THREE.Mesh(new THREE.CylinderGeometry(24, 32, 74, 9),
      new THREE.MeshLambertMaterial({ color: 0xf6e8d6 }));
    stem.position.y = 37;
    const capGeo = new THREE.SphereGeometry(54, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2);
    const cap = new THREE.Mesh(capGeo, new THREE.MeshLambertMaterial({ color: u.tier ? 0x74c7dd : 0xe88d84 }));
    cap.position.y = 72;
    cap.scale.y = 0.78;
    const eyeMat = new THREE.MeshBasicMaterial({ color: 0x33241e });
    [-1, 1].forEach(s => {
      const e = new THREE.Mesh(new THREE.SphereGeometry(3.4, 6, 6), eyeMat);
      e.position.set(30, 40, s * 12);
      g.add(e);
    });
    g.add(stem); g.add(cap);
    g.userData = { cap };
  }
  g.position.set(u.x, 0, u.y);
  g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; if (!isBase) o.material = o.material.clone(); } });
  if (!isBase) w3dRegisterOccluder(g);
  W3D.scene.add(g);
  u.__mesh = g;
  W3D.propMeshes.push(g);
  return g;
}

/* 地面圆环特效（技能范围、命中圈、减速区） */
function w3dRing(x, y, r, color, opacity, life) {
  const THREE = window.THREE;
  let slot = null;
  for (const it of W3D.rings) {
    if (it.until < performance.now() / 1000) { slot = it; break; }
  }
  if (!slot) {
    if (W3D.rings.length > 40) return;
    const geo = new THREE.RingGeometry(0.86, 1, 28);
    const mat = new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false, side: THREE.DoubleSide });
    const mesh = new THREE.Mesh(geo, mat);
    mesh.rotation.x = -Math.PI / 2;
    W3D.scene.add(mesh);
    slot = { mesh, mat, until: 0 };
    W3D.rings.push(slot);
  }
  slot.mesh.position.set(x, 1.4, y);
  slot.mesh.scale.setScalar(Math.max(6, r));
  slot.mat.color.set(color);
  slot.mat.opacity = opacity;
  slot.until = performance.now() / 1000 + (life || 0.25);
}

/* ---------- 动画驱动：把 anim.js 的 pose 通道映射到骨骼 ---------- */
function w3dApplyHero(h, rig, pose, dt, time) {
  const p = rig.parts, root = rig.root, H = rig.height;
  const moving = pose.moving;
  const walkPhase = (h.walkT || 0) * 7.4;
  const swing = moving ? Math.sin(walkPhase) : 0;
  const atk = pose.atk || 0, cast = pose.cast || 0, hurt = pose.hurt || 0;
  const dying = pose.dying, deathP = pose.deathP || 0;

  /* 根：位置、朝向、跳跃与倾斜 */
  const faceSign = h.facing >= 0 ? 1 : -1;
  const lunge3 = (atk > 0 ? atk * 9 : 0) - (hurt > 0 ? hurt * 7 * (h.hitDir || 1) * faceSign : 0);
  root.position.x = h.x + lunge3 * faceSign;
  root.position.z = h.y;
  const lift = (pose.lift || 0) + (moving ? Math.abs(swing) * 2.6 : 0) + (pose.bob || 0) * 0.6;
  root.position.y = lift;
  const wantYaw = h.facing >= 0 ? 0 : Math.PI;
  root.rotation.y = w3dAngleDamp(root.rotation.y, wantYaw, 12, dt);

  /* 大招旋转：整圈自转 */
  if (pose.spinRaw > 0) root.rotation.y += pose.spinRaw * Math.PI * 4;

  /* 阵亡：绕脚向后倒下并下沉 */
  const topple = dying ? -deathP * 1.45 : 0;
  root.rotation.z = topple + (pose.lean || 0) * 0.55;
  root.position.y = lift - (dying ? deathP * 6 : 0);

  /* 躯干：挤压拉伸、侧倾，以及最关键的"转体发力" */
  if (p.body) {
    const sq = 1 + (pose.squashY - 1) * 0.9;
    p.body.scale.set(1 / Math.max(0.2, sq), sq, 1 / Math.max(0.2, sq));
    /* 出招时先反向拧腰再甩出去；走路时轻微反向扭动做对侧步态 */
    const twist = atk < 0
      ? atk * 0.55
      : atk * 0.62 + (moving ? swing * 0.1 : Math.sin(time * 1.1 + h.seed) * 0.03);
    p.body.rotation.y = w3dDamp(p.body.rotation.y, twist, 20, dt);
    /* 俯仰：前冲压身、受击仰身、施法后坐 */
    p.body.rotation.x = (atk > 0 ? atk * 0.22 : 0) - hurt * 0.26 - cast * 0.12;
    p.body.rotation.z = -(pose.lean || 0) * 0.35;   /* 骨架约定：负值=向前压 */
  }

  /* 腿 */
  const legAmp = moving ? 0.78 : 0;
  if (p.legFL) p.legFL.rotation.z = swing * legAmp;
  if (p.legFR) p.legFR.rotation.z = -swing * legAmp;
  if (p.legBL) p.legBL.rotation.z = -swing * legAmp * 0.85;
  /* 手臂：挥击走前后摆动（rotation.z 正=向前），施法走两侧上举（rotation.x） */
  if (p.armR) {
    const swingR = atk !== 0
      ? -0.18 + atk * 1.55                     /* 蓄力时 atk<0，手自然甩到身后 */
      : (moving ? -swing * 0.4 - 0.1 : -0.1 + Math.sin(time * 1.9 + h.seed) * 0.05);
    p.armR.rotation.z = w3dDamp(p.armR.rotation.z, swingR, 20, dt);
    p.armR.rotation.x = w3dDamp(p.armR.rotation.x, cast > 0.05 ? -cast * 1.5 : 0, 14, dt);
  }
  if (p.armL) {
    const swingL = atk !== 0
      ? -0.18 + atk * 0.5
      : (moving ? swing * 0.4 - 0.1 : -0.1 + Math.sin(time * 1.9 + h.seed + 1.2) * 0.05);
    p.armL.rotation.z = w3dDamp(p.armL.rotation.z, swingL, 16, dt);
    p.armL.rotation.x = w3dDamp(p.armL.rotation.x, cast > 0.05 ? cast * 1.5 : 0, 14, dt);
  }


  /* 头：出招压低、施法抬头、受击后仰，平时随呼吸轻摆 */
  if (p.head) {
    const idleNod = Math.sin(time * 1.6 + h.seed) * 0.04;
    p.head.rotation.z = (atk > 0 ? -0.16 : 0) + (cast > 0 ? 0.14 : 0) - hurt * 0.3 + idleNod;
    p.head.rotation.x = Math.sin(time * 0.9 + h.seed * 1.7) * 0.05 - (atk > 0 ? atk * 0.16 : 0) + cast * 0.18;
    if (p.body) {
      /* 头部滞后于躯干转动，形成自然的跟随 */
      const lag = w3dDamp(h.__headLag || 0, p.body.rotation.y, 9, dt);
      h.__headLag = lag;
      p.head.rotation.y = -lag * 0.55;
    }
  }

  /* 眨眼 */
  if (p.eyes) {
    const bp = ((time * 0.42 + h.seed * 0.31) % 1);
    const close = (bp < 0.05 ? Math.sin(bp / 0.05 * Math.PI) : 0) * 0.9 + (hurt > 0.5 ? 0.35 : 0) + (dying ? 1 : 0);
    p.eyes.scale.y = Math.max(0.08, 1 - Math.min(1, close));
  }

  /* 尾巴/耳朵等次级运动：滞后跟随身体 */
  if (!h.__lag) h.__lag = { v: 0, t: 0 };
  const bodyTilt = p.body ? p.body.rotation.z : 0;
  h.__lag.v = w3dDamp(h.__lag.v, bodyTilt, 8, dt);
  h.__lag.t = w3dDamp(h.__lag.t, h.__lag.v, 6, dt);
  if (p.tail) {
    p.tail.rotation.y = Math.sin(time * 2.6 + h.seed) * 0.35 + (moving ? swing * 0.4 : 0) + h.__lag.t * 1.4;
    p.tail.rotation.z = -0.25 + (cast > 0 ? -0.5 : 0) + (atk > 0 ? 0.5 : 0) + h.__lag.v * 0.8;
  }
  if (p.earL) p.earL.rotation.z = Math.sin(time * 2.1 + h.seed) * 0.12 - hurt * 0.4;
  if (p.earR) p.earR.rotation.z = Math.sin(time * 2.1 + h.seed + 1) * 0.12 - hurt * 0.4;
  if (p.weapon) {
    /* 基准位置只在第一次记录，否则每帧累加会让武器飘上天 */
    const ud = p.weapon.userData || (p.weapon.userData = {});
    if (ud.__baseY == null) ud.__baseY = p.weapon.position.y;
    if (ud.__baseRz == null) ud.__baseRz = p.weapon.rotation.z;
    p.weapon.rotation.z = ud.__baseRz + atk * 0.95 - cast * 0.55;
    p.weapon.position.y = ud.__baseY + cast * 3;
  }

  /* 选中环与队伍光环由 2D 层画，这里只做脚下阴影感 */
  root.visible = true;
  const base = HERO_SCALE_3D;
  root.scale.setScalar(dying ? Math.max(0.06 * base, base * (1 - deathP)) : base);
}

/* 连续掉帧时单向关掉阴影：一次性的决定，避免画质来回抖 */
function w3dAutoQuality(dt) {
  if (W3D.lowQ) return;
  W3D.slowAcc = (W3D.slowAcc || 0) + (dt > 0.026 ? dt : 0);
  W3D.fastAcc = (W3D.fastAcc || 0) + (dt <= 0.022 ? dt : 0);
  if (W3D.slowAcc > 2.4 && W3D.fastAcc < 0.5) {
    W3D.lowQ = true;
    W3D.renderer.shadowMap.enabled = false;
    W3D.sun.castShadow = false;
    W3D.scene.traverse(o => { if (o.isMesh && o.material) o.material.needsUpdate = true; });
    console.warn('[W3D] 帧率偏低，已关闭实时阴影以保流畅');
  }
}

/* ---------- 每帧 ---------- */
function w3dFrame(world, timeSec, dt) {
  if (!W3D.ok) return false;
  const THREE = window.THREE;
  const cw = W3D.view.w, ch = W3D.view.h;
  if (!cw || !ch) return false;

  /* 相机：跟随玩家，死亡时继续停在原地 */
  const focus = (typeof player !== 'undefined' && player && (player.alive || player.deathT > 0))
    ? player
    : { x: world.bases.blue.x, y: world.bases.blue.y, moveDir: { x: 0, y: 0 }, facing: 1 };
  const lead = 90;
  const tx = focus.x + (focus.moveDir ? focus.moveDir.x * lead : 0);
  const ty = focus.y + (focus.moveDir ? focus.moveDir.y * lead * 0.6 : 0);
  W3D.camTarget.x = w3dDamp(W3D.camTarget.x, tx, 5.2, dt);
  W3D.camTarget.y = w3dDamp(W3D.camTarget.y, ty, 5.2, dt);

  const punch = 1 + (world.zoomPunch || 0) * 0.05;
  /* 视口越矮（手机横屏）镜头越近，否则角色在 430px 高的屏幕上太小 */
  const camK = Math.min(1, Math.max(0.7, W3D.view.h / 760));
  const dist = 690 * camK / punch;
  const height = 520 * camK / punch;
  const shake = world.shake > 0.1 ? world.shake : 0;
  const sx = shake ? (Math.random() - 0.5) * shake * 2.2 : 0;
  const sy = shake ? (Math.random() - 0.5) * shake * 1.6 : 0;
  W3D.camera.position.set(W3D.camTarget.x + sx, height, W3D.camTarget.y + dist + sy);
  W3D.camera.lookAt(W3D.camTarget.x, 30, W3D.camTarget.y - 46);
  W3D.camera.aspect = cw / ch;
  W3D.camera.updateProjectionMatrix();

  /* 遮挡淡出：比主角更靠近镜头的树/灌木/塔变半透明，别挡住战场 */
  w3dUpdateOccluders(dt);
  w3dAutoQuality(dt);

  /* 阴影相机跟着镜头走，保证影子始终精细 */
  W3D.sun.position.set(W3D.camTarget.x + 520, 900, W3D.camTarget.y + 380);
  W3D.sun.target.position.set(W3D.camTarget.x, 0, W3D.camTarget.y);
  W3D.sun.target.updateMatrixWorld();

  /* 英雄 */
  const seen = new Set();
  for (const h of world.heroes) {
    seen.add(h.uid);
    const rig = w3dHeroRig(h);
    const pose = buildPose(h, timeSec);
    if (!h.alive && (!h.deathT || h.deathT <= 0)) { rig.root.visible = false; continue; }
    w3dApplyHero(h, rig, pose, dt, timeSec);
  }
  for (const [uid, rig] of W3D.heroRigs) {
    if (!seen.has(uid)) rig.root.visible = false;
  }

  /* 小兵 */
  for (const m of world.units) {
    if (m.kind !== 'minion') continue;
    const mesh = w3dMinionMesh(m);
    mesh.visible = !!m.alive;
    if (!m.alive) continue;
    const wp = (m.walkT || 0) * 8;
    const hop = Math.abs(Math.sin(wp));
    mesh.position.set(m.x, hop * 3.2, m.y);
    mesh.rotation.y = m.facing >= 0 ? 0 : Math.PI;
    const ud = mesh.userData;
    const sq = 1 + (m.atkAnim > 0 ? Math.sin((1 - m.atkAnim / 0.22) * Math.PI) * 0.12 : 0);
    ud.body.scale.set(1 / sq, 1.12 * sq, 1 / sq);
    ud.eyes.scale.y = Math.max(0.1, 1 - hop * 0.1);
  }

  /* 塔与水晶 */
  for (const u of world.units) {
    if (u.kind !== 'tower' && u.kind !== 'base') continue;
    const mesh = w3dStructureMesh(u);
    mesh.visible = !!u.alive;
    if (!u.alive) continue;
    const recoil = u.atkAnim > 0 ? Math.sin((1 - u.atkAnim / 0.32) * Math.PI) : 0;
    const ud = mesh.userData;
    if (ud && ud.cap) ud.cap.position.y = 72 - recoil * 7;
    if (ud && ud.crystal) {
      ud.crystal.rotation.y = timeSec * 0.35;
      ud.crystal.position.y = 96 + Math.sin(timeSec * 1.4) * 4 - recoil * 8;
    }
  }

  /* 蜂蜜 */
  for (const pk of world.pickups) {
    if (pk.alive && !pk.__mesh) {
      const g = new THREE.Group();
      const pot = new THREE.Mesh(new THREE.CylinderGeometry(20, 15, 24, 10),
        new THREE.MeshLambertMaterial({ color: 0xd9a05b }));
      pot.position.y = 12;
      const lid = new THREE.Mesh(new THREE.CylinderGeometry(21, 21, 5, 10),
        new THREE.MeshLambertMaterial({ color: 0xf2c879 }));
      lid.position.y = 26;
      const star = new THREE.Mesh(new THREE.SphereGeometry(5, 8, 6),
        new THREE.MeshLambertMaterial({ color: 0xfff0b8 }));
      star.position.set(0, 32, 0);
      g.add(pot); g.add(lid); g.add(star);
      g.position.set(pk.x, 0, pk.y);
      g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
      g.userData = { star };
      W3D.scene.add(g);
      pk.__mesh = g;
    }
    if (pk.__mesh && pk.__mesh.userData.star) {
      pk.__mesh.userData.star.position.y = 32 + Math.sin(timeSec * 2.2 + pk.seed) * 3;
    }
    if (pk.__mesh) pk.__mesh.visible = !!pk.alive;
  }

  /* 投射物 */
  const shotPool = W3D.shots;
  let si = 0;
  for (const pr of world.projectiles) {
    let slot = shotPool[si];
    if (!slot) {
      const THREE3 = window.THREE;
      const mesh = new THREE3.Mesh(new THREE3.SphereGeometry(6, 8, 6),
        new THREE3.MeshBasicMaterial({ transparent: true }));
      mesh.castShadow = false;
      W3D.scene.add(mesh);
      slot = { mesh, mat: mesh.material };
      shotPool.push(slot);
    }
    slot.mesh.visible = true;
    slot.mesh.position.set(pr.x, 26, pr.y);
    const st = pr.style || 'bolt';
    slot.mesh.scale.setScalar((pr.size || 6) / 6 * (st === 'bubble' ? 1.6 : 1.15));
    slot.mat.color.set(pr.color || '#ffe6a3');
    slot.mat.opacity = st === 'bubble' ? 0.62 : 0.95;
    si++;
  }
  for (; si < shotPool.length; si++) shotPool[si].mesh.visible = false;

  /* 地面特效环 */
  for (const e of world.effects) {
    if (e.type === 'ring' || e.type === 'warn') {
      const p = Math.min(1, e.t / e.life);
      const r = e.type === 'warn' ? (e.r || 90) : (e.r0 + (e.r1 - e.r0) * (1 - Math.pow(1 - p, 2)));
      w3dRing(e.x, e.y, r, e.color || '#ffe6a3', (1 - p) * 0.75, e.life - e.t);
    }
  }
  const now = performance.now() / 1000;
  for (const it of W3D.rings) {
    if (it.until < now) it.mesh.visible = false;
    else it.mesh.visible = true;
  }

  W3D.renderer.render(W3D.scene, W3D.camera);
  return true;
}

/* ---------- 3D → 屏幕投影（2D 层用它画名字/血条/伤害数字） ---------- */
function w3dProject(x, y, above) {
  const THREE = window.THREE;
  if (!W3D.ok) return null;
  _v3.set(x, above == null ? 0 : above, y).project(W3D.camera);
  const cw = W3D.view.w, ch = W3D.view.h;
  return {
    x: ( _v3.x * 0.5 + 0.5) * cw,
    y: (-_v3.y * 0.5 + 0.5) * ch,
    on: _v3.z < 1 && _v3.x > -1.35 && _v3.x < 1.35 && _v3.y > -1.35 && _v3.y < 1.35,
    depth: _v3.z
  };
}
let _v3 = null;

function w3dResize(w, h) {
  W3D.view.w = w; W3D.view.h = h;
  if (!W3D.ok) return;
  const THREE = window.THREE;
  if (!_v3) _v3 = new THREE.Vector3();
  W3D.renderer.setSize(w, h, false);
  W3D.camera.aspect = w / h;
  W3D.camera.updateProjectionMatrix();
}

function w3dAvailable() {
  try {
    const c = document.createElement('canvas');
    return !!(window.THREE && (c.getContext('webgl2') || c.getContext('webgl')));
  } catch (e) { return false; }
}
