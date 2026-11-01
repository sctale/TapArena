'use strict';
/* ============================================================
   萌兽峡谷 · hero-rigs.js
   Three.js 低多边形「毛绒玩具」角色骨架（6 个英雄）
   ------------------------------------------------------------
   对外契约：
     HERO_RIGS[heroId]() -> { root, parts, height }
       root   : THREE.Group，原点在脚底与地面接触点，面朝 +X，站在 y=0
       parts  : body head earL earR armL armR legFL legFR legBL legBR tail weapon eyes
                （全部存在，用不到的是 null）
       height : 头顶高度（世界单位，用包围盒自动量出，不打进 noMeasure 挂件）

   枢轴约定（主渲染层直接给 rotation 就行）：
     · 角色面朝 +X，"上"= +Y，左右 = ±Z。
     · 腿/臂 group 的原点在髋/肩，内部网格 mesh.position.y = -肢体长/2，
       所以 rotation.z 绕关节前后摆（>0 向 +X 甩），rotation.x 侧向张开，rotation.y 扭转。
     · 注意 body 的 rotation.z 符号和腿相反：body.rotation.z < 0 才是前压。
     · 尾 group 原点在尾根，网格向 -X 延伸；rotation.z < 0 抬尾，rotation.y 左右摆。
     · 头 group 原点在脖子（body 的子节点），网格向 +Y 偏移。
     · body 是躯干 group（原点在腹部下缘），head / 双臂 / 尾巴挂在它下面；
       4 条腿挂在 root 上，所以躯干 squash 不会把腿拉长。
     · parts.eyes 是装着两只眼珠 + 高光的合并网格的 group，eyes.scale.y 做眨眼。

   造型手法：躯干/头都是一个椭球 + 若干「外壳片」。shell() 造出与躯干同形状、
   只放大 2~7% 或沿某轴压扁的椭球，它只在露出毛面的那一片可见，所以肚皮、条纹、
   鞍毛、裙摆都服帖，不会像贴了个球一样鼓出来。所有静态装饰用 merge() 按顶点色
   合并进宿主网格，因此围巾/帽子/花环/尖刺/背带都不额外占 mesh。
   每角色 mesh 数：虎 12 / 狐 13 / 兔 12 / 熊 13 / 獭 13 / 猬 11（上限 14）。
   材质统一 MeshLambertMaterial（场景只有半球光 + 平行光）。
   配色读 www/js/data.js 的 HERO_DEFS（fur / furDark / cream / accent），
   data.js 不在时退回 DEFAULT_PAL，本文件可独立使用。
   ============================================================ */
(function (global) {
  const THREE = global.THREE;
  if (!THREE) { global.HERO_RIGS = {}; return; }

  /* ---------------------------------------------------------
     配色
     --------------------------------------------------------- */
  const DEFAULT_PAL = {
    tiger:    { fur: '#f7a94f', furDark: '#c9752f', cream: '#fff2da', accent: '#2f9c8f' },
    fox:      { fur: '#f8cd92', furDark: '#d18b49', cream: '#fff7e6', accent: '#7d5cd6' },
    rabbit:   { fur: '#fff7f3', furDark: '#f0c2cc', cream: '#ffe9ee', accent: '#f27ea8' },
    bear:     { fur: '#b98155', furDark: '#8d5c39', cream: '#ffe9cf', accent: '#5a8f5f' },
    otter:    { fur: '#7f9fc4', furDark: '#5b7ba0', cream: '#f4faff', accent: '#3fb5c9' },
    hedgehog: { fur: '#c9b18f', furDark: '#8a6f52', cream: '#fff1dd', accent: '#e0685f' }
  };

  function tint(hex, target, k) { const c = new THREE.Color(hex); c.lerp(new THREE.Color(target), k); return '#' + c.getHexString(); }
  function mul(hex, k) { const c = new THREE.Color(hex); c.multiplyScalar(k); return '#' + c.getHexString(); }

  function palOf(id) {
    const def = (global.HERO_DEFS && global.HERO_DEFS[id]) || {};
    const f = DEFAULT_PAL[id];
    const p = {
      fur: def.fur || f.fur, furDark: def.furDark || f.furDark,
      cream: def.cream || f.cream, accent: def.accent || f.accent
    };
    p.dark = mul(p.furDark, 0.8);             // 鼻头/描边
    p.light = tint(p.fur, '#ffffff', 0.32);   // 高光绒毛
    p.earIn = tint(p.cream, p.accent, 0.34);  // 耳内
    p.nose = tint(p.furDark, '#2b1d18', 0.66);
    return p;
  }

  /* ---------------------------------------------------------
     低段数几何体缓存（Sphere <=10x8，Cylinder/Cone 6~9 段）
     --------------------------------------------------------- */
  const GEO = new Map();
  function cache(key, make) {
    let g = GEO.get(key);
    if (!g) { g = make(); GEO.set(key, g); }
    return g;
  }
  const SPH = (r, w, h) => cache('S' + r + ',' + (w || 10) + ',' + (h || 8),
    () => new THREE.SphereGeometry(r, w || 10, h || 8));
  const CYL = (rt, rb, h, s) => cache('C' + rt + ',' + rb + ',' + h + ',' + (s || 7),
    () => new THREE.CylinderGeometry(rt, rb, h, s || 7, 1));
  const CN = (r, h, s) => cache('N' + r + ',' + h + ',' + (s || 7),
    () => new THREE.ConeGeometry(r, h, s || 7));
  const BX = (w, h, d) => cache('B' + w + ',' + h + ',' + d,
    () => new THREE.BoxGeometry(w, h, d));
  const TOR = (r, t, rs, ts) => cache('T' + r + ',' + t + ',' + (rs || 4) + ',' + (ts || 10),
    () => new THREE.TorusGeometry(r, t, rs || 4, ts || 10));
  /* 五角星（ExtrudeGeometry，只给法杖用一次） */
  const STAR = (ro, ri, d) => cache('X' + ro + ',' + ri + ',' + d, () => {
    const sh = new THREE.Shape();
    for (let i = 0; i < 10; i++) {
      const a = Math.PI / 2 + i * Math.PI / 5;
      const r = (i % 2) ? ri : ro;
      const x = Math.cos(a) * r, y = Math.sin(a) * r;
      if (i) sh.lineTo(x, y); else sh.moveTo(x, y);
    }
    sh.closePath();
    return new THREE.ExtrudeGeometry(sh, { depth: d, bevelEnabled: false, steps: 1 });
  });

  /* ---------------------------------------------------------
     merge()：若干几何体变换后合成一个带顶点色的几何体
     item = { geo, x,y,z, rx,ry,rz, sx,sy,sz, c }
     --------------------------------------------------------- */
  const _m4 = new THREE.Matrix4(), _q = new THREE.Quaternion();
  const _eu = new THREE.Euler(), _pv = new THREE.Vector3(), _sv = new THREE.Vector3();
  const COLC = new Map();
  function colOf(hex) {
    let c = COLC.get(hex);
    if (!c) { c = new THREE.Color(hex); COLC.set(hex, c); }
    return c;
  }
  const one = (v) => (v === undefined ? 1 : v);

  function merge(items) {
    const pos = [], nrm = [], cls = [];
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      const src = it.geo.index ? it.geo.toNonIndexed() : it.geo.clone();
      _eu.set(it.rx || 0, it.ry || 0, it.rz || 0);
      _q.setFromEuler(_eu);
      _pv.set(it.x || 0, it.y || 0, it.z || 0);
      _sv.set(one(it.sx), one(it.sy), one(it.sz));
      _m4.compose(_pv, _q, _sv);
      src.applyMatrix4(_m4);
      const pa = src.attributes.position.array, na = src.attributes.normal.array;
      const c = colOf(it.c);
      for (let k = 0; k < pa.length; k += 3) {
        pos.push(pa[k], pa[k + 1], pa[k + 2]);
        nrm.push(na[k], na[k + 1], na[k + 2]);
        cls.push(c.r, c.g, c.b);
      }
      src.dispose();
    }
    const out = new THREE.BufferGeometry();
    out.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    out.setAttribute('normal', new THREE.Float32BufferAttribute(nrm, 3));
    out.setAttribute('color', new THREE.Float32BufferAttribute(cls, 3));
    out.computeBoundingSphere();
    return out;
  }

  function M(geo, mat) {
    const m = new THREE.Mesh(geo, mat);
    m.castShadow = true;
    return m;
  }
  function G(parent, x, y, z) {
    const g = new THREE.Group();
    g.position.set(x, y, z);
    parent.add(g);
    return g;
  }

  /* 躯干外壳片：和躯干同形状，放大 k 倍 / 沿某轴再压扁 / 整体偏移，
     只在露出的那一片可见 —— 肚皮、条纹、鞍毛、裙摆都靠它 */
  function shell(b, o) {
    const k = one(o.k);
    return {
      geo: SPH(b.r, 10, 8),
      x: (b.x || 0) + (o.dx || 0), y: b.y + (o.dy || 0), z: o.dz || 0,
      sx: b.sx * k * one(o.fx), sy: b.sy * k * one(o.fy), sz: b.sz * k * one(o.fz),
      rz: o.rz || 0, c: o.c
    };
  }
  /* 沿椭球表面撒一圈扁球 = 服帖的"带子"（斜挎背带 / 水草领） */
  function band(b, o) {
    const items = [];
    const ry = b.r * b.sy, rz = b.r * b.sz;
    const n = o.n || 9;
    for (let i = 0; i <= n; i++) {
      const t = o.a0 + (o.a1 - o.a0) * i / n;
      items.push({
        geo: SPH(o.r, 7, 6),
        x: (b.x || 0) + (o.dx || 0) + (o.xk || 0) * t,
        y: b.y + (o.dy || 0) + Math.cos(t) * ry * one(o.k),
        z: Math.sin(t) * rz * one(o.k),
        rx: t, sx: one(o.w), sy: one(o.thin), sz: 1, c: o.c
      });
    }
    return items;
  }
  /* 沿背脊法线放射的尖刺：每根 = 下段截锥 + 上段圆锥，两色且半径连续 */
  function spikes(b, o) {
    const items = [];
    const rx = b.r * b.sx, ry = b.r * b.sy;
    for (let i = 0; i < o.n; i++) {
      const t = o.a0 + (o.a1 - o.a0) * i / (o.n - 1);
      const x = (b.x || 0) + Math.sin(t) * rx * one(o.k);
      const y = b.y + Math.cos(t) * ry * one(o.k);
      let nx = Math.sin(t) / rx, ny = Math.cos(t) / ry;
      const L = Math.hypot(nx, ny); nx /= L; ny /= L;
      const ang = Math.atan2(-nx, ny);
      const h = (typeof o.h === 'function') ? o.h(i) : o.h;
      const r = (typeof o.r === 'function') ? o.r(i) : o.r;
      const zs = o.rows || [0];
      for (const z of zs) {
        const bx = x - nx * h * 0.18, by = y - ny * h * 0.18;   // 刺根略埋进毛里
        items.push({ geo: CYL(r * 0.46, r, h * 0.55, 6), x: bx + nx * h * 0.275, y: by + ny * h * 0.275, z, rz: ang, c: (i % 2) ? o.c : o.c2 });
        items.push({ geo: CN(r * 0.46, h * 0.45, 6), x: bx + nx * h * 0.775, y: by + ny * h * 0.775, z, rz: ang, c: o.tip });
      }
    }
    return items;
  }
  /* 折线毛绒尾巴：段 + 关节球，适合圆滚滚的尾（虎） */
  function tailFrom(pts) {
    const items = [];
    for (let i = 0; i < pts.length - 1; i++) {
      const a = pts[i], b = pts[i + 1];
      const dx = b.x - a.x, dy = b.y - a.y, L = Math.hypot(dx, dy);
      const ang = Math.atan2(dy, dx) - Math.PI / 2;
      items.push({ geo: CYL(a.r, b.r, L, 6), x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, rz: ang, c: a.c });
      items.push({ geo: SPH(a.r * 0.94, 7, 6), x: a.x, y: a.y, c: a.c });
    }
    const e = pts[pts.length - 1];
    items.push({ geo: SPH(e.r, 8, 6), x: e.x, y: e.y, sx: 1, sy: 1, sz: 0.95, c: e.c });
    return items;
  }
  /* 蓬松尾巴：沿切线拉长的椭球首尾相接，没有台阶感（狐的白尾 / 獭的扁尾） */
  function puffTail(pts, o) {
    o = o || {};
    const items = [];
    for (let i = 0; i < pts.length; i++) {
      const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)], c = pts[i];
      const ang = Math.atan2(b.y - a.y, b.x - a.x);
      items.push({
        geo: SPH(c.r, 9, 7), x: c.x, y: c.y, z: c.z || 0, rz: ang,
        sx: one(o.sx), sy: one(o.sy), sz: one(o.sz), c: c.c
      });
    }
    return items;
  }

  /* 头顶高度：量包围盒，跳过打了 noMeasure 标记的挂件（水獭的水泡） */
  function measureHeight(root) {
    root.updateWorldMatrix(true, true);
    const box = new THREE.Box3();
    let top = 0;
    root.traverse(function (o) {
      if (!o.isMesh) return;
      let skip = false, q = o;
      while (q && q !== root) { if (q.userData && q.userData.noMeasure) { skip = true; break; } q = q.parent; }
      if (skip) return;
      const g = o.geometry;
      if (!g.boundingBox) g.computeBoundingBox();
      box.copy(g.boundingBox).applyMatrix4(o.matrixWorld);
      if (box.max.y > top) top = box.max.y;
    });
    return +top.toFixed(2);
  }

  /* ---------------------------------------------------------
     buildPlush(o)：毛绒四足 + 双前爪的通用装配
     --------------------------------------------------------- */
  function buildPlush(o) {
    const p = o.pal;
    const vc = new THREE.MeshLambertMaterial({ vertexColors: true }); // 每骨架一套，便于主层按英雄换色/闪白
    const parts = {
      body: null, head: null, earL: null, earR: null, armL: null, armR: null,
      legFL: null, legFR: null, legBL: null, legBR: null, tail: null, weapon: null, eyes: null
    };
    const root = new THREE.Group();
    if (o.scale) root.scale.setScalar(o.scale);
    const rig = { root: root, parts: parts, height: 0, mats: {} };

    /* ---- 躯干 group（原点在腹部下缘，squash 向上长） ---- */
    const b = o.body;
    const body = G(root, 0, b.pivot, 0);
    parts.body = body;
    const torso = [{ geo: SPH(b.r, 10, 8), x: b.x || 0, y: b.y, z: 0, sx: b.sx, sy: b.sy, sz: b.sz, c: p.fur }];
    if (b.belly) torso.push(shell(b, { dx: b.belly.dx, dy: b.belly.dy, k: one(b.belly.k), c: b.belly.c || p.cream }));
    if (b.saddle) torso.push(shell(b, { dx: b.saddle.dx, dy: b.saddle.dy, k: one(b.saddle.k), fy: b.saddle.fy, fx: b.saddle.fx, c: b.saddle.c || p.furDark }));
    if (o.bodyDeco) for (const d of o.bodyDeco) { if (Array.isArray(d)) torso.push.apply(torso, d); else torso.push(d); }
    body.add(M(merge(torso), vc));

    /* ---- 头（脖子枢轴，挂在 body 下） ---- */
    const h = o.head;
    const head = G(body, h.neck.x, h.neck.y, 0);
    parts.head = head;
    const hr = h.r;
    const headItems = [{ geo: SPH(hr, 10, 8), y: hr * one(h.sy), z: 0, sx: one(h.sx), sy: one(h.sy), sz: one(h.sz), c: p.fur }];
    if (h.muzzle) {
      const q = h.muzzle;
      headItems.push({ geo: SPH(q.r, 9, 7), x: q.x, y: q.y, z: q.z || 0, sx: one(q.sx), sy: one(q.sy), sz: one(q.sz), rz: q.rz || 0, c: q.c || p.cream });
    }
    if (h.nose) headItems.push({ geo: SPH(h.nose.r, 7, 6), x: h.nose.x, y: h.nose.y, z: 0, sx: one(h.nose.sx), sy: one(h.nose.sy), sz: one(h.nose.sz), c: h.nose.c || p.nose });
    if (o.headDeco) for (const d of o.headDeco) { if (Array.isArray(d)) headItems.push.apply(headItems, d); else headItems.push(d); }
    head.add(M(merge(headItems), vc));

    /* ---- 眼睛（一个合并 mesh 装 2 瞳 + 2 高光） ---- */
    if (o.eyes) {
      const e = o.eyes, items = [];
      const eyeG = G(head, e.pos.x, e.pos.y, 0);
      parts.eyes = eyeG;
      for (const s of [-1, 1]) {
        items.push({ geo: SPH(e.r, 8, 6), x: e.bx || 0, y: 0, z: s * e.gap, sx: one(e.sx), sy: 1, sz: 1, c: '#2c211d' });
        items.push({ geo: SPH(e.r * 0.34, 6, 5), x: (e.bx || 0) + e.r * 0.6, y: e.r * 0.44, z: s * e.gap * 0.92, c: '#ffffff' });
      }
      eyeG.add(M(merge(items), vc));
    }

    /* ---- 耳朵 ---- */
    if (o.ears) {
      const mk = (side) => {
        const g = G(head, o.ears.pos.x, o.ears.pos.y, side * o.ears.pos.z);
        g.add(M(merge(o.ears.items(p, side)), vc));
        return g;
      };
      parts.earL = mk(-1);
      parts.earR = mk(1);
    }

    /* ---- 腿：4 条，枢轴在髋，挂在 root（不被躯干 squash 拉长） ---- */
    const lg = o.legs;
    const mkLeg = (name, x, z) => {
      const g = G(root, x, lg.hipY, z);
      const items = [{ geo: CYL(lg.r * 0.9, lg.r, lg.len, 6), c: lg.c || p.fur }];
      items.push({ geo: SPH(lg.r * 1.16, 8, 6), x: lg.r * 0.42, y: -lg.len / 2 + lg.r * 0.4, z: 0, sx: 1.18, sy: 0.6, sz: 1.12, c: lg.pawC || p.cream });
      const mesh = M(merge(items), vc);
      mesh.position.y = -lg.len / 2;   // ← 枢轴在髋
      g.add(mesh);
      parts[name] = g;
    };
    mkLeg('legFL', lg.fx, lg.z);
    mkLeg('legFR', lg.fx, -lg.z);
    mkLeg('legBL', lg.bx, lg.z);
    mkLeg('legBR', lg.bx, -lg.z);

    /* ---- 手臂：枢轴在肩，挂在 body ---- */
    if (o.arms) {
      const a = o.arms;
      const mkArm = (name, side) => {
        const g = G(body, a.x, a.y, side * a.z);
        const items = [{ geo: CYL(a.r * 0.86, a.r, a.len, 6), c: a.c || p.fur }];
        items.push({ geo: SPH(a.r * 1.2, 9, 7), x: a.r * 0.34, y: -a.len / 2 + a.r * 0.24, z: 0, sx: 1.05, sy: 0.94, sz: 1.1, c: p.cream });
        if (a.pad) items.push({ geo: SPH(a.r * 0.55, 7, 5), x: a.r * 0.9, y: -a.len / 2, z: 0, sx: 0.6, sy: 0.8, sz: 1, c: p.earIn });
        const mesh = M(merge(items), vc);
        mesh.position.y = -a.len / 2;   // ← 枢轴在肩
        g.add(mesh);
        return g;
      };
      parts.armL = mkArm('armL', -1);
      parts.armR = mkArm('armR', 1);
    }

    /* ---- 尾巴：枢轴在尾根，网格向 -X 延伸 ---- */
    if (o.tail) {
      const t = G(body, o.tail.x, o.tail.y, 0);
      t.add(M(merge(o.tail.items(p)), vc));
      parts.tail = t;
    }

    /* ---- 武器：挂在点名的手臂末端 ---- */
    if (o.weapon && parts[o.weapon.arm]) {
      const w = o.weapon;
      const wg = new THREE.Group();
      wg.position.set(w.at.x, w.at.y, w.at.z);
      if (w.rot) wg.rotation.set(w.rot.x || 0, w.rot.y || 0, w.rot.z || 0);
      parts[w.arm].add(wg);
      wg.add(M(merge(w.items(p), vc), vc));
      parts.weapon = wg;
    }

    /* ---- 额外整件（半透明水泡等） ---- */
    if (o.extras) o.extras(rig, p);

    rig.height = measureHeight(root);
    return rig;
  }

  /* ---------------------------------------------------------
     常用耳型（枢轴在耳根，网格向 +Y 长）
     --------------------------------------------------------- */
  function roundEar(pal, r) {
    return () => ([
      { geo: SPH(r, 8, 6), y: r * 0.72, sx: 1, sy: 0.95, sz: 0.78, c: pal.fur },
      { geo: SPH(r * 0.6, 7, 5), x: r * 0.48, y: r * 0.76, sx: 0.5, sy: 0.85, sz: 0.72, c: pal.earIn }
    ]);
  }
  function smallEar(pal, r, inner) {
    return () => ([
      { geo: SPH(r, 8, 6), x: r * 0.1, y: r * 0.62, sx: 0.95, sy: 0.85, sz: 0.8, c: pal.furDark },
      { geo: SPH(r * 0.52, 7, 5), x: r * 0.5, y: r * 0.6, sx: 0.45, sy: 0.75, sz: 0.7, c: inner || pal.cream }
    ]);
  }
  function pointyEar(pal, r, hgt, lean) {
    return (side) => ([
      { geo: CN(r, hgt, 6), y: hgt * 0.46, rx: side * one(lean), c: pal.furDark },
      { geo: CN(r * 0.55, hgt * 0.66, 5), x: r * 0.42, y: hgt * 0.4, rx: side * one(lean), c: pal.earIn }
    ]);
  }
  /* 长耳（兔）：枢轴在耳根，向 +Y 长 len，略向外侧倒 */
  function longEar(pal, r, len, lean) {
    return (side) => ([
      { geo: CYL(r * 0.72, r, len * 0.82, 6), y: len * 0.42, rx: side * lean, rz: -side * 0.05, sx: 1, sy: 1, sz: 0.62, c: pal.fur },
      { geo: SPH(r * 0.74, 8, 6), y: len * 0.85, z: 0, rx: side * lean, sx: 1, sy: 1.15, sz: 0.6, c: pal.fur },
      { geo: CYL(r * 0.4, r * 0.52, len * 0.6, 5), x: r * 0.46, y: len * 0.4, rx: side * lean, sx: 1, sy: 1, sz: 0.42, c: pal.earIn },
      { geo: SPH(r * 0.42, 7, 5), x: r * 0.46, y: len * 0.72, rx: side * lean, sx: 0.9, sy: 1.2, sz: 0.36, c: pal.earIn }
    ]);
  }

  /* =========================================================
     1) tiger 阿虎 · 战士 · 中等敦实
        mesh 12 = 躯干1(橙毛+奶油肚皮+3道环身条纹+青绿围巾) 头1(含额纹/口鼻/鼻头)
                   耳2 眼1 臂2(奶油掌球) 腿4(奶油脚掌) 尾1(长尾+2道深环+奶油尾尖)
        身高 ~38
     ========================================================= */
  function buildTigerRig() {
    const p = palOf('tiger');
    const LEG = 10.6;
    const body = { pivot: 11.8, r: 9.6, x: 0, y: 8.8, sx: 1.16, sy: 0.99, sz: 0.9 };
    const head = {
      r: 5.8, sx: 1.06, sy: 0.94, sz: 0.98, neck: { x: 9.6, y: 14.4 },
      muzzle: { x: 4.0, y: 2.8, r: 3.0, sx: 1.1, sy: 0.8, sz: 1.35 },
      nose: { x: 6.4, y: 5.0, r: 0.9, sx: 0.8, sy: 0.68, sz: 1.1 }
    };
    const hr = head.r;
    return buildPlush({
      pal: p, scale: 0.96, body: body, head: head,
      /* 奶油肚皮：躯干外壳片向前下偏移，只在腹面露出 */
      bodyDeco: [
        shell(body, { dx: 0.9, dy: -1.1, k: 1.018, c: p.cream }),
        /* 三道环身条纹：与躯干同形、只沿 X 压扁成薄片，放大 7% 后从毛面露出 */
        shell(body, { dx: -6.4, k: 1.07, fx: 0.085, c: p.furDark }),
        shell(body, { dx: -2.2, k: 1.07, fx: 0.09, c: p.furDark }),
        shell(body, { dx: 2.0, k: 1.065, fx: 0.09, c: p.furDark }),
        /* 围巾：套在脖子根部的环 + 结 + 垂下一角 */
        { geo: TOR(4.5, 1.5, 5, 10), x: 7.6, y: 13.6, ry: Math.PI / 2, c: p.accent },
        { geo: SPH(1.9, 8, 6), x: 7.4, y: 15.0, z: 3.2, sx: 1, sy: 0.85, sz: 1, c: tint(p.accent, '#ffffff', 0.2) },
        { geo: BX(2.2, 4.6, 2.0), x: 6.2, y: 11.4, z: 4.2, rz: 0.4, rx: -0.2, c: p.accent }
      ],
      headDeco: [
        /* 额头两道深色纹：贴在脑门上的小扁斑，不绕成头箍 */
        { geo: SPH(1.0, 7, 6), x: 0.8, y: hr * 1.86, z: 1.5, sx: 1.5, sy: 0.28, sz: 0.55, c: p.furDark },
        { geo: SPH(1.0, 7, 6), x: 0.8, y: hr * 1.86, z: -1.5, sx: 1.5, sy: 0.28, sz: 0.55, c: p.furDark }
      ],
      eyes: { r: 1.18, gap: 2.35, pos: { x: 5.3, y: 6.3 }, bx: 0.5, sx: 0.7 },
      ears: { pos: { x: 1.2, y: 9.4, z: 3.6 }, items: roundEar(p, 2.05) },
      legs: { len: LEG, r: 3.0, hipY: LEG + 0.9, fx: 7.2, bx: -8.4, z: 4.9 },
      arms: { len: 7.8, r: 2.25, x: 7.4, y: 11.2, z: 5.3, pad: true },
      tail: {
        x: -10.6, y: 9.4, items: (pal) => {
          const pts = [
            { x: 0, y: 0, r: 2.5, c: pal.fur },
            { x: -4.4, y: 0.4, r: 2.2, c: pal.fur },
            { x: -8.2, y: 2.4, r: 1.85, c: pal.fur },
            { x: -11.2, y: 5.6, r: 1.55, c: pal.fur },
            { x: -12.6, y: 9.2, r: 1.4, c: pal.cream }
          ];
          const items = tailFrom(pts);
          /* 两道深色尾环：短圆柱套在尾段上 */
          items.push({ geo: CYL(2.28, 2.34, 1.5, 6), x: -4.6, y: 0.45, rz: Math.PI / 2 + 0.09, c: pal.furDark });
          items.push({ geo: CYL(1.95, 2.0, 1.4, 6), x: -8.4, y: 2.65, rz: Math.PI / 2 + 0.52, c: pal.furDark });
          return items;
        }
      }
    });
  }

  /* =========================================================
     2) fox 灵灵 · 法师 · 纤细，大白尾 + 紫巫师帽 + 星形法杖
        mesh 13 = 躯干1(含肚皮/颈毛领) 头1(含吻/颊毛/巫师帽) 耳2 眼1 臂2 腿4
                  尾1(蓬松大白尾) 法杖1(细圆柱+五角星+光珠)
        身高 ~38（含帽）
     ========================================================= */
  function buildFoxRig() {
    const p = palOf('fox');
    const LEG = 9.8;
    const body = { pivot: 10.4, r: 8.6, x: 0, y: 8.2, sx: 1.16, sy: 0.92, sz: 0.78 };
    const head = { r: 5.0, sx: 1.02, sy: 0.92, sz: 0.94, neck: { x: 8.4, y: 12.4 } };
    const purple = p.accent, purpleLite = tint(purple, '#ffffff', 0.24);
    return buildPlush({
      pal: p, scale: 0.94, body: body, head: head,
      bodyDeco: [
        shell(body, { dx: 0.8, dy: -0.9, k: 1.018, c: p.cream }),
        /* 颈后深色毛领 */
        { geo: TOR(3.9, 1.3, 4, 10), x: 6.4, y: 11.6, ry: Math.PI / 2, rz: 0.15, c: p.furDark }
      ],
      headDeco: [
        /* 巫师帽：帽檐（8 边压扁圆柱）+ 圆锥 + 帽带 + 帽尖小垂 */
        { geo: CYL(5.7, 6.1, 0.9, 8), x: 0.3, y: 8.1, c: purple },
        { geo: CN(2.9, 6.4, 7), x: 0.3, y: 11.3, rz: 0.14, c: purple },
        { geo: CYL(3.1, 3.6, 1.2, 8), x: 0.35, y: 8.9, c: purpleLite },
        { geo: SPH(0.8, 7, 6), x: 1.2, y: 14.4, z: 0.5, c: '#ffe08a' },
        { geo: SPH(0.55, 6, 5), x: 4.0, y: 8.6, z: 2.2, c: '#fff0b8' },
        /* 尖吻 + 小黑鼻 + 两撮颊毛 */
        { geo: CN(2.2, 4.0, 7), x: 5.6, y: 3.6, rz: -Math.PI / 2, c: p.cream },
        { geo: SPH(0.85, 7, 6), x: 7.6, y: 3.6, sx: 0.85, sy: 0.7, sz: 1, c: p.nose },
        { geo: SPH(1.35, 7, 6), x: 1.2, y: 2.8, z: 3.4, sx: 0.9, sy: 0.75, sz: 0.7, c: p.cream },
        { geo: SPH(1.35, 7, 6), x: 1.2, y: 2.8, z: -3.4, sx: 0.9, sy: 0.75, sz: 0.7, c: p.cream }
      ],
      eyes: { r: 1.05, gap: 2.05, pos: { x: 4.4, y: 5.3 }, bx: 0.35, sx: 0.75 },
      ears: { pos: { x: 1.0, y: 5.6, z: 3.5 }, items: pointyEar(p, 2.2, 4.9, 0.34) },
      legs: { len: LEG, r: 2.45, hipY: LEG + 0.7, fx: 6.2, bx: -7.2, z: 3.9, c: p.furDark },
      arms: { len: 7.2, r: 1.95, x: 6.2, y: 9.8, z: 4.4 },
      tail: {
        x: -9.0, y: 8.8, items: (pal) => puffTail([
          { x: 0, y: -0.4, r: 2.2, c: pal.fur },
          { x: -3.4, y: 0.4, r: 2.9, c: pal.cream },
          { x: -7.2, y: 2.2, r: 3.5, c: pal.cream },
          { x: -10.6, y: 4.8, r: 3.2, c: pal.cream },
          { x: -13.0, y: 7.4, r: 2.3, c: pal.fur }
        ], { sx: 1.5, sy: 1.02, sz: 1.0 })
      },
      weapon: {
        arm: 'armR', at: { x: 0.9, y: -6.4, z: 0.5 }, rot: { x: -0.18, y: 0, z: 0.16 },
        items: (pal) => ([
          /* 细杖身（大部分露在手掌上方）+ 顶部五角星 + 星前光珠 + 握把星环 */
          { geo: CYL(0.5, 0.72, 15, 6), y: 4.0, c: '#a9764a' },
          { geo: SPH(0.85, 6, 5), y: -3.0, c: '#8a5f39' },
          { geo: STAR(3.1, 1.35, 1.2), x: 0, y: 13.2, z: -0.6, c: '#ffdf8a' },
          { geo: SPH(0.95, 7, 6), x: 0.2, y: 13.4, z: 0.8, c: '#fff8dc' },
          { geo: TOR(1.35, 0.42, 4, 8), y: 9.8, rx: Math.PI / 2, c: pal.accent }
        ])
      }
    });
  }

  /* =========================================================
     3) rabbit 朵朵 · 辅助 · 小巧白兔
        mesh 12 = 躯干1(含肚皮+粉色裙摆+裙边) 头1(含花环/腮毛/粉鼻) 耳2(超长)
                  眼1 臂2 腿4 尾1(圆球尾)
        身高 ~31（含长耳）
     ========================================================= */
  function buildRabbitRig() {
    const p = palOf('rabbit');
    const LEG = 7.2;
    const body = { pivot: 8.0, r: 7.2, x: 0, y: 6.4, sx: 1.02, sy: 1.02, sz: 0.94 };
    const head = {
      r: 4.6, sx: 1.0, sy: 0.98, sz: 1.04, neck: { x: 5.0, y: 10.4 },
      muzzle: { x: 3.0, y: 2.2, r: 2.1, sx: 1.05, sy: 0.8, sz: 1.2 },
      nose: { x: 4.9, y: 2.6, r: 0.62, sx: 0.9, sy: 0.72, sz: 1.0, c: p.earIn }
    };
    const pink = p.accent, petal = '#fff4c8';
    return buildPlush({
      pal: p, scale: 0.87, body: body, head: head,
      bodyDeco: [
        shell(body, { dx: 0.6, dy: -0.7, k: 1.018, c: p.cream }),
        /* 裙摆：开口向下的宽喇叭（截锥），上沿藏进身子、下摆露成一圈 */
        { geo: CYL(5.0, 10.6, 5.0, 9), x: -1.0, y: 0.2, c: pink },
        { geo: CYL(10.7, 10.7, 0.9, 9), x: -1.0, y: -2.1, c: tint(pink, '#ffffff', 0.32) },
        { geo: SPH(0.95, 6, 5), x: 3.4, y: -1.9, z: 7.4, c: petal },
        { geo: SPH(0.95, 6, 5), x: -1.2, y: -1.9, z: -8.2, c: petal },
        { geo: SPH(0.95, 6, 5), x: -5.0, y: -1.9, z: 6.6, c: petal }
      ],
      headDeco: [
        /* 头顶小花：5 瓣 + 黄心 */
        { geo: SPH(0.72, 6, 5), x: 1.2, y: 9.9, z: 1.5, c: pink },
        { geo: SPH(0.72, 6, 5), x: 1.2, y: 9.9, z: -0.6, c: pink },
        { geo: SPH(0.72, 6, 5), x: 0.2, y: 9.7, z: 0.45, c: pink },
        { geo: SPH(0.72, 6, 5), x: 2.2, y: 9.7, z: 0.45, c: pink },
        { geo: SPH(0.62, 6, 5), x: 1.2, y: 10.6, z: 0.45, c: '#ffe08a' },
        { geo: SPH(0.6, 6, 5), x: 1.2, y: 9.1, z: 0.45, c: petal }
      ],
      eyes: { r: 1.0, gap: 2.1, pos: { x: 4.2, y: 5.2 }, bx: 0.4, sx: 0.76 },
      ears: { pos: { x: -0.4, y: 7.6, z: 2.4 }, items: longEar(p, 1.9, 7.6, 0.3) },
      legs: { len: LEG, r: 2.5, hipY: LEG + 0.6, fx: 4.4, bx: -4.6, z: 3.5, c: p.fur },
      arms: { len: 5.6, r: 1.85, x: 4.8, y: 8.2, z: 3.9 },
      tail: {
        x: -6.6, y: 6.0, items: (pal) => ([
          { geo: SPH(2.1, 8, 6), x: -1.2, y: 0.3, sx: 1, sy: 1, sz: 0.95, c: pal.cream }
        ])
      }
    });
  }

  /* =========================================================
     4) bear 阿岳 · 坦克 · 最高最宽
        mesh 13 = 躯干1(含大肚皮+深色鞍毛) 头1(含口鼻/鼻头/眉) 耳2 眼1
                  臂2(肉垫) 腿4 尾1(小 nub) 荷叶盾1(8 边压扁盘+波浪边+叶脉)
        身高 ~50
     ========================================================= */
  function buildBearRig() {
    const p = palOf('bear');
    const LEG = 13.6;
    const body = { pivot: 15.0, r: 13.2, x: 0, y: 11.2, sx: 1.06, sy: 1.02, sz: 0.98 };
    const head = {
      r: 7.4, sx: 1.02, sy: 0.95, sz: 1.0, neck: { x: 10.2, y: 19.0 },
      muzzle: { x: 5.2, y: 3.4, r: 3.5, sx: 1.05, sy: 0.82, sz: 1.25 },
      nose: { x: 8.6, y: 4.4, r: 1.3, sx: 0.88, sy: 0.72, sz: 1.1 }
    };
    const hr = head.r;
    const leaf = p.accent, leafLite = tint(leaf, '#ffffff', 0.18), leafDark = mul(leaf, 0.72);
    return buildPlush({
      pal: p, body: body, head: head,
      bodyDeco: [
        shell(body, { dx: 1.0, dy: -1.3, k: 1.018, c: p.cream }),
        /* 肩背深色鞍毛：外壳片向上偏，只在背脊露出 */
        shell(body, { dy: 2.4, k: 1.02, fy: 0.52, fx: 0.86, c: p.furDark })
      ],
      headDeco: [
        /* 两道短眉（只压在眼睛上方，不连成片） */
        { geo: BX(1.5, 1.2, 2.6), x: hr * 0.74, y: hr * 1.34, z: 2.5, rz: -0.2, c: p.furDark },
        { geo: BX(1.5, 1.2, 2.6), x: hr * 0.74, y: hr * 1.34, z: -2.5, rz: -0.2, c: p.furDark },
        /* 后脑勺深色帽毛：外壳片向后偏，只在头顶后方露出 */
        shell({ r: hr, x: 0, y: hr * 0.95, sx: 1.02, sy: 0.95, sz: 1.0 }, { dx: -2.6, dy: 1.3, k: 1.015, fy: 0.46, c: p.furDark })
      ],
      eyes: { r: 1.2, gap: 3.0, pos: { x: 6.3, y: 8.3 }, bx: 0.5, sx: 0.7 },
      ears: { pos: { x: 1.2, y: 12.0, z: 5.3 }, items: smallEar(p, 2.5, p.cream) },
      legs: { len: LEG, r: 4.1, hipY: LEG + 1.2, fx: 8.4, bx: -10.2, z: 6.5 },
      arms: { len: 10.0, r: 3.0, x: 9.2, y: 15.6, z: 7.4, pad: true },
      tail: {
        x: -14.0, y: 12.4, items: (pal) => ([
          { geo: SPH(2.0, 7, 6), x: -0.9, y: 0.1, sx: 1, sy: 1, sz: 0.9, c: pal.furDark }
        ])
      },
      weapon: {
        /* 左手荷叶盾：盘面朝前略外展 */
        arm: 'armL', at: { x: 2.0, y: -8.0, z: -1.6 }, rot: { x: 0, y: 0.42, z: 0 },
        items: (pal) => {
          const items = [
            { geo: CYL(7.4, 6.8, 1.6, 8), rz: Math.PI / 2, c: leaf },
            { geo: CYL(5.6, 5.6, 0.7, 8), rz: Math.PI / 2, sx: 1, sy: 1.2, sz: 1.2, c: leafDark },
            { geo: SPH(1.9, 8, 6), x: -1.2, sx: 0.7, sy: 1.05, sz: 1.05, c: pal.cream }
          ];
          for (let i = 0; i < 8; i++) {
            const a = i * Math.PI / 4 + 0.39;
            items.push({
              geo: SPH(2.0, 7, 5), x: 0.1,
              y: Math.cos(a) * 6.7, z: Math.sin(a) * 6.7,
              sx: 0.7, c: (i % 2) ? leaf : leafLite
            });
          }
          items.push({ geo: BX(0.5, 11.6, 1.0), x: 0.85, c: leafDark });
          items.push({ geo: BX(0.5, 1.0, 11.2), x: 0.85, y: 0.4, c: leafDark });
          return items;
        }
      }
    });
  }

  /* =========================================================
     5) otter 泡泡 · 控制 · 流线瘦长
        mesh 13 = 躯干1(含奶油胸+背脊流线+水草领) 头1(含吻/鼻/颊) 耳2 眼1
                  臂2(蹼爪) 腿4 尾1(扁平大尾) 水泡1(半透明，单独材质)
        身高 ~37（水泡不打进身高）
     ========================================================= */
  function buildOtterRig() {
    const p = palOf('otter');
    const LEG = 9.0;
    const body = { pivot: 9.6, r: 9.0, x: -0.6, y: 8.0, sx: 1.3, sy: 0.9, sz: 0.76 };
    const head = {
      r: 4.9, sx: 1.04, sy: 0.9, sz: 1.0, neck: { x: 8.4, y: 11.4 },
      muzzle: { x: 3.7, y: 2.3, r: 2.3, sx: 1.15, sy: 0.8, sz: 1.2 },
      nose: { x: 5.9, y: 2.9, r: 0.85, sx: 0.9, sy: 0.7, sz: 1.05 }
    };
    const weed = '#3fae7a', weedDark = '#2e7d57';
    return buildPlush({
      pal: p, scale: 1.17, body: body, head: head,
      bodyDeco: [
        shell(body, { dx: 0.9, dy: -0.8, k: 1.018, c: p.cream }),
        /* 背脊深色流线 */
        shell(body, { dx: -1.6, dy: 2.0, k: 1.02, fy: 0.46, fx: 0.8, c: p.furDark }),
        /* 脖子一圈水草：细环 + 三片叶子 */
        { geo: TOR(4.1, 0.85, 4, 10), x: 7.4, y: 11.6, ry: Math.PI / 2, rz: 0.22, c: weed },
        { geo: SPH(1.2, 7, 5), x: 8.0, y: 14.0, z: 2.2, sx: 0.45, sy: 1.5, sz: 0.45, rz: 0.3, c: weedDark },
        { geo: SPH(1.1, 7, 5), x: 7.0, y: 13.8, z: -2.4, sx: 0.42, sy: 1.35, sz: 0.42, rz: -0.3, c: weed },
        { geo: SPH(1.0, 7, 5), x: 5.8, y: 14.4, z: 0.8, sx: 0.4, sy: 1.25, sz: 0.4, c: weedDark }
      ],
      headDeco: [
        { geo: SPH(1.05, 7, 6), x: -1.4, y: 7.9, z: 1.6, sx: 0.8, sy: 1.3, sz: 0.8, c: p.furDark },
        { geo: SPH(1.0, 7, 6), x: 0.6, y: 8.3, z: -1.4, sx: 0.75, sy: 1.2, sz: 0.75, c: p.furDark }
      ],
      eyes: { r: 1.02, gap: 2.1, pos: { x: 4.7, y: 5.4 }, bx: 0.4, sx: 0.74 },
      ears: { pos: { x: -0.4, y: 7.0, z: 3.15 }, items: smallEar(p, 1.3, p.earIn) },
      legs: { len: LEG, r: 2.55, hipY: LEG + 0.6, fx: 6.4, bx: -7.6, z: 3.9 },
      arms: { len: 6.8, r: 2.0, x: 6.4, y: 9.2, z: 4.2, pad: true },
      tail: {
        /* 扁平大尾巴：沿切线拉长的椭球，竖直压扁、横向放宽 */
        x: -11.0, y: 7.6, items: (pal) => puffTail([
          { x: 0, y: -0.4, r: 2.1, c: pal.furDark },
          { x: -3.8, y: 0.2, r: 2.7, c: pal.fur },
          { x: -8.0, y: 1.1, r: 3.1, c: pal.fur },
          { x: -11.8, y: 2.4, r: 2.6, c: pal.furDark },
          { x: -14.2, y: 3.4, r: 1.9, c: pal.cream }
        ], { sx: 1.5, sy: 0.4, sz: 1.35 })
      },
      extras: (rig, pal) => {
        /* 头顶浮一颗半透明水泡（合并成 1 个 mesh，单独透明材质，不打进身高） */
        const grp = new THREE.Group();
        grp.position.set(3.0, 10.2, 0);
        grp.userData.noMeasure = true;
        const mat = new THREE.MeshLambertMaterial({ color: 0xffffff, transparent: true, opacity: 0.45, depthWrite: false, vertexColors: true });
        const geo = merge([
          { geo: SPH(2.3, 10, 8), c: '#dff3ff' },
          { geo: SPH(0.7, 6, 5), x: 1.2, y: 1.1, z: 0.9, c: '#ffffff' }
        ]);
        const ball = new THREE.Mesh(geo, mat);
        ball.castShadow = false;
        grp.add(ball);
        rig.parts.head.add(grp);
        rig.mats.bubble = mat;
      }
    });
  }

  /* =========================================================
     6) hedgehog 尖尖 · 射手 · 最矮小
        mesh 11 = 躯干1(含奶油肚皮+8根背刺+红色斜挎背带) 头1(含尖吻/黑鼻/额毛)
                  耳2 眼1 臂2 腿4
        身高 ~29
     ========================================================= */
  function buildHedgehogRig() {
    const p = palOf('hedgehog');
    const LEG = 6.2;
    const body = { pivot: 6.8, r: 7.0, x: -0.4, y: 6.0, sx: 1.14, sy: 0.98, sz: 0.96 };
    const head = { r: 4.2, sx: 1.0, sy: 0.94, sz: 1.0, neck: { x: 6.2, y: 9.0 } };
    const spikeA = tint(p.cream, p.furDark, 0.14), spikeB = p.cream, spikeTip = p.furDark;
    return buildPlush({
      pal: p, scale: 1.18, body: body, head: head,
      bodyDeco: [
        shell(body, { dx: 0.7, dy: -0.8, k: 1.018, c: p.cream }),
        /* 背上 8 根锥形尖刺：沿背脊法线放射，左右各一列 */
        spikes(body, {
          n: 4, a0: -0.85, a1: 0.55, k: 1.0, rows: [-2.9, 2.9],
          r: (i) => 1.55 - Math.abs(i - 1.5) * 0.16, h: (i) => 5.6 - Math.abs(i - 1.5) * 0.7,
          c: spikeA, c2: spikeB, tip: spikeTip
        }),
        /* 红色斜挎背带：沿躯干表面的一圈扁球带 */
        band(body, { a0: -1.85, a1: 1.85, n: 20, r: 1.5, k: 1.02, thin: 0.26, w: 1.2, dx: 0.4, xk: 1.15, c: p.accent }),
        { geo: SPH(1.0, 7, 6), x: 2.0, y: 11.2, z: 4.6, c: tint(p.accent, '#ffffff', 0.35) }
      ],
      headDeco: [
        /* 尖吻 + 黑鼻头 */
        { geo: CN(2.0, 3.4, 7), x: 4.8, y: 3.0, rz: -Math.PI / 2, c: p.cream },
        { geo: SPH(0.8, 7, 6), x: 6.5, y: 3.0, sx: 0.9, sy: 0.72, sz: 1, c: p.nose },
        /* 脸侧两小撮浅色毛 */
        { geo: SPH(1.15, 7, 5), x: 1.6, y: 2.6, z: 3.0, sx: 0.9, sy: 0.7, sz: 0.7, c: p.cream },
        { geo: SPH(1.15, 7, 5), x: 1.6, y: 2.6, z: -3.0, sx: 0.9, sy: 0.7, sz: 0.7, c: p.cream }
      ],
      eyes: { r: 0.95, gap: 1.95, pos: { x: 4.0, y: 4.5 }, bx: 0.35, sx: 0.78 },
      ears: { pos: { x: 0.2, y: 6.4, z: 2.9 }, items: smallEar(p, 1.35, p.earIn) },
      legs: { len: LEG, r: 2.2, hipY: LEG + 0.5, fx: 4.2, bx: -4.8, z: 3.3, c: p.furDark },
      arms: { len: 5.2, r: 1.7, x: 5.0, y: 7.4, z: 3.4 }
    });
  }

  global.HERO_RIGS = {
    tiger: buildTigerRig,
    fox: buildFoxRig,
    rabbit: buildRabbitRig,
    bear: buildBearRig,
    otter: buildOtterRig,
    hedgehog: buildHedgehogRig
  };
  /* 调试用：建模小工具挂出去，方便主层或后续角色复用 */
  global.HERO_RIG_UTIL = {
    merge: merge, shell: shell, band: band, spikes: spikes, tailFrom: tailFrom,
    palOf: palOf, buildPlush: buildPlush, DEFAULT_PAL: DEFAULT_PAL,
    SPH: SPH, CYL: CYL, CN: CN, BX: BX, TOR: TOR, STAR: STAR, tint: tint, mul: mul
  };
})(typeof window !== 'undefined' ? window : globalThis);
