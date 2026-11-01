/* ============================================================
   stage.js —— Phaser 3 特效层（WebGL 粒子 + 镜头脉冲）
   ------------------------------------------------------------
   为什么只把特效交给 Phaser，而不是整个渲染层：
     · 角色是程序化 Canvas 路径画的，改成引擎贴图要重画全部美术，
       而实测下来角色绘制并不是性能瓶颈（1.5× 降频仍有 55fps）。
     · Canvas2D 真正吃亏的是"大量小粒子"：火花、尘土、花瓣一多就掉帧。
       Phaser 的 WebGL 粒子池可以同屏几千颗而不掉帧。
   所以：世界逻辑与角色仍由 game.js / render.js 负责，
        打击火花、脚底尘土、技能星屑交给这一层，Phaser 不可用时自动退回 Canvas 特效。

   对外接口（game.js 调用）：
     StageFX.ready                     是否可用
     StageFX.setEnabled(bool)          战斗界面切换
     StageFX.hit(x, y, {color,big,dir})   命中迸溅
     StageFX.dust(x, y, color)            脚底尘土
     StageFX.spark(x, y, color, count)    技能星屑
     StageFX.pulse(strength)              镜头缩放脉冲
   ============================================================ */

/* 显存不够时 WebGL 会抛 "Framebuffer status: Incomplete Attachment"。
   这里按特效层将要占用的真实尺寸先探测一次，探测不过就直接用 Phaser 的 Canvas 渲染器，
   避免把 GL 错误抛到页面上。 */
function fxGLUsable(w, h) {
  try {
    const c = document.createElement('canvas');
    c.width = Math.max(64, Math.floor(w));
    c.height = Math.max(64, Math.floor(h));
    const gl = c.getContext('webgl') || c.getContext('experimental-webgl');
    if (!gl) return false;
    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, c.width, c.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    const fb = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
    const ok = gl.checkFramebufferStatus(gl.FRAMEBUFFER) === gl.FRAMEBUFFER_COMPLETE;
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.deleteFramebuffer(fb);
    gl.deleteTexture(tex);
    const lose = gl.getExtension('WEBGL_lose_context');
    if (lose) lose.loseContext();
    return ok;
  } catch (e) {
    return false;
  }
}
const StageFX = {
  ready: false,
  game: null,
  scene: null,
  _pulse: 0,

  failed: false,

  boot() {
    if (window.__FX_DISABLE || this.failed || this.game || this.ready || typeof Phaser === 'undefined' || !window.__FX_VIEW) return;
    const parent = document.getElementById('fxStage');
    if (!parent) return;
    const pw = parent.clientWidth || (window.__FX_VIEW ? window.__FX_VIEW().w : 0) || window.innerWidth;
    const ph = parent.clientHeight || (window.__FX_VIEW ? window.__FX_VIEW().h : 0) || window.innerHeight;
    if (pw < 64 || ph < 64) return;   /* 容器还没尺寸，等下一次再试 */
    if (!window.__FX_FORCE_WEBGL_TEST && !fxGLUsable(pw, ph)) { this.failed = true; return; }
    const view = window.__FX_VIEW();
    const cfg = {
      type: Phaser.WEBGL,
      parent,
      dom: false,
      scale: {
        mode: Phaser.Scale.RESIZE,
        autoCenter: Phaser.Scale.NO_CENTER,
        width: Math.max(320, pw),
        height: Math.max(200, ph)
      },
      /* transparent 必须放在 render 下，顶层写法 Phaser 不认，会画成不透明黑底 */
      render: { transparent: true, antialias: false },
      scene: FxScene
    };
    this._guardErrors();
    try {
      this.game = new Phaser.Game(cfg);
    } catch (e) {
      /* 同步异常（比如没有 GL 上下文）：直接放弃特效层 */
      this._releaseGuard();
      console.warn('[StageFX] Phaser 启动失败，退回 Canvas 特效：', e && e.message);
      this.failed = true;
      return;
    }
    /* 兜底：2 秒内场景没建起来就彻底放弃，交回 Canvas 特效 */
    setTimeout(() => {
      if (!this.ready && this.game) {
        this._releaseGuard();
        /* 拿不到可用的 WebGL 就彻底放弃这一层：Phaser 的 Canvas 渲染器
           并不比原来的 Canvas 特效更省，低端机实测反而更慢 */
        console.warn('[StageFX] WebGL 不可用，特效层停用，交回原 Canvas 特效');
        this.game.destroy(true);
        this.game = null;
        this.scene = null;
        this.failed = true;
        const box = document.getElementById('fxStage');
        if (box) box.style.display = 'none';
      }
    }, 2000);
  },

  setEnabled(on) {
    const parent = document.getElementById('fxStage');
    if (parent) parent.style.display = on ? 'block' : 'none';
    if (this.scene) this.scene.setActiveFx(!!on);
  },

  /* 世界坐标 → 屏幕坐标（与 renderWorld 使用同一组相机参数） */
  toScreen(x, y) {
    const v = window.__FX_VIEW();
    return { x: (x - v.cx) * v.scale + v.w / 2 + v.sx, y: (y - v.cy) * v.scale + v.h / 2 + v.sy };
  },

  hit(x, y, opt) {
    if (!this.ready || !this.scene) return false;
    try { this.scene.burstHit(this.toScreen(x, y), opt || {}); return true; }
    catch (e) { this.disable(e); return false; }
  },
  dust(x, y, color) {
    if (!this.ready || !this.scene) return false;
    try { this.scene.puffDust(this.toScreen(x, y), color); return true; }
    catch (e) { this.disable(e); return false; }
  },
  spark(x, y, color, count) {
    if (!this.ready || !this.scene) return false;
    try { this.scene.fairySpark(this.toScreen(x, y), color, count || 8); return true; }
    catch (e) { this.disable(e); return false; }
  },

  _guardErrors() {
    if (this._guarded) return;
    this._guarded = true;
    this._prevOnError = window.onerror;
    const self = this;
    window.onerror = function (msg) {
      const text = typeof msg === 'string' ? msg : (msg && msg.message) || '';
      if (text.indexOf('Framebuffer status') >= 0) {
        /* Phaser 的 WebGL 渲染目标建不出来，交给看门狗换渲染器重试，不污染页面报错 */
        return true;
      }
      return self._prevOnError ? self._prevOnError.apply(window, arguments) : false;
    };
  },

  _releaseGuard() {
    if (!this._guarded) return;
    this._guarded = false;
    window.onerror = this._prevOnError || null;
    this._prevOnError = null;
  },

  /* 一旦特效层出错就彻底退回 Canvas 路径，绝不让战斗卡住 */
  disable(e) {
    if (!this.ready) return;
    console.warn('[StageFX] 特效层异常，退回 Canvas 特效：', e && e.message);
    this.ready = false;
    this.failed = true;
    this.setEnabled(false);
  },
  pulse(v) {
    if (!this.ready) return;
    this._pulse = Math.min(1.4, Math.max(this._pulse, v || 0.6));
  }
};

class FxScene extends Phaser.Scene {
  constructor() { super('fx'); }

  create() {
    /* 粒子贴图全部程序化生成，保持零外部资源。
       注意：每张纹理必须用独立的 Graphics 实例，复用同一个对象连续
       generateTexture 会得到不完整的帧缓冲（WebGL 直接抛错）。 */
    const bake = (key, size, draw) => {
      if (this.textures.exists(key)) return;
      const gr = this.make.graphics({ x: 0, y: 0, add: false });
      draw(gr, size);
      gr.generateTexture(key, size, size);
      gr.destroy();
    };
    let fail = null;
    try {
      bake('fx-dot', 12, (gr, s) => { gr.fillStyle(0xffffff, 1); gr.fillCircle(s / 2, s / 2, s / 2 - 0.6); });
      bake('fx-soft', 16, (gr, s) => {
        gr.fillStyle(0xffffff, 0.45); gr.fillCircle(s / 2, s / 2, s / 2);
        gr.fillStyle(0xffffff, 0.35); gr.fillCircle(s / 2, s / 2, s / 2 - 3);
      });
      bake('fx-star', 20, (gr, s) => {
        const cx = s / 2, cy = s / 2, R = s / 2 - 1, r = R * 0.34;
        gr.fillStyle(0xffffff, 1);
        gr.beginPath();
        for (let i = 0; i < 8; i++) {
          const rad = i % 2 ? r : R;
          const a = (i * Math.PI) / 4 - Math.PI / 2;
          const px = cx + Math.cos(a) * rad, py = cy + Math.sin(a) * rad;
          if (i) gr.lineTo(px, py); else gr.moveTo(px, py);
        }
        gr.closePath();
        gr.fillPath();
      });

      this.fxOn = true;
      this.emitters = {
        hit: this.add.particles(0, 0, 'fx-dot', {
          speed: { min: 90, max: 300 },
          angle: { min: 0, max: 360 },
          scale: { start: 1.1, end: 0 },
          alpha: { start: 1, end: 0 },
          lifespan: 380,
          gravityY: 320,
          emitting: false
        }),
        spark: this.add.particles(0, 0, 'fx-star', {
          speed: { min: 30, max: 150 },
          scale: { start: 0.9, end: 0 },
          rotate: { min: 0, max: 360 },
          alpha: { start: 1, end: 0 },
          lifespan: 620,
          emitting: false
        }),
        dust: this.add.particles(0, 0, 'fx-soft', {
          speedX: { min: -40, max: 40 },
          speedY: { min: -70, max: -20 },
          scale: { start: 0.5, end: 1.5 },
          alpha: { start: 0.55, end: 0 },
          lifespan: 520,
          emitting: false
        })
      };
    } catch (e) {
      fail = e;
    }
    if (fail) {
      console.warn('[StageFX] 场景初始化失败，回退 Canvas 特效：', fail.message);
      return;
    }
    StageFX.ready = true;
    StageFX.scene = this;
    StageFX._releaseGuard();
  }

  setActiveFx(on) { this.fxOn = on; }

  /* Phaser 各版本着色接口名字不同，这里探测一次后缓存 */
  tintOf(em, value) {
    if (!em) return;
    if (!em.__tintFn) {
      em.__tintFn = typeof em.setParticleTint === 'function' ? 'setParticleTint'
        : (typeof em.setColor === 'function' ? 'setColor' : null);
    }
    if (!em.__tintFn) return;
    try { em[em.__tintFn](value); } catch (e) { em.__tintFn = null; }
  }

  burstHit(pos, opt) {
    if (!this.fxOn) return;
    const color = Phaser.Display.Color.HexStringToColor(opt.color || '#ffe4a2').color;
    const big = opt.big ? 1.7 : 1;
    const count = Math.round(14 * big);
    /* Phaser 3.90 的发射器没有 setSpeed/setColor，只有 setParticle* 系列 */
    this.tintOf(this.emitters.hit, color);
    this.emitters.hit.setQuantity(count);
    this.emitters.hit.setParticleScale(1.1 * big, 0);
    this.emitters.hit.emitParticleAt(pos.x, pos.y, count);
    if (opt.big) {
      this.emitters.spark.setQuantity(5);
      this.emitters.spark.emitParticleAt(pos.x, pos.y, 5);
    }
    this.emitters.spark.emitParticleAt(pos.x, pos.y, opt.big ? 4 : 2);
  }

  puffDust(pos, color) {
    if (!this.fxOn) return;
    const c = Phaser.Display.Color.HexStringToColor(color || '#e8f0e0').color;
    this.tintOf(this.emitters.dust, c);
    this.emitters.dust.emitParticleAt(pos.x, pos.y, 2);
  }

  fairySpark(pos, color, count) {
    if (!this.fxOn) return;
    const c = Phaser.Display.Color.HexStringToColor(color || '#fff3b8').color;
    this.tintOf(this.emitters.spark, c);
    this.emitters.spark.setQuantity(count);
    this.emitters.spark.emitParticleAt(pos.x, pos.y, count);
  }
}

/* 启动：等 game.js 暴露 __FX_VIEW 之后再 boot */
function stageFxTryBoot() {
  if (StageFX.ready || typeof Phaser === 'undefined' || !window.__FX_VIEW) return;
  StageFX.boot();
}

if (typeof document !== 'undefined') {
  window.addEventListener('load', () => {
    stageFxTryBoot();
    setTimeout(stageFxTryBoot, 400);
  });
}
