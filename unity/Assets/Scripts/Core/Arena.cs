using System.Collections.Generic;
using UnityEngine;

namespace TapArena
{
    public class Unit
    {
        public int uid;
        public UnitKind kind;
        public Team team;
        public HeroDef def;          // 仅英雄
        public HeroId heroId;
        public string name = "";

        public Vector3 pos;          // y 恒为 0，高度由视图决定
        public float facing = 1f;    // +1 朝右 / -1 朝左
        public Vector3 moveDir;

        public float hp, maxHp, dmg, range, atkInterval, atkTimer, moveSpeed, radius, height;
        public int level = 1;
        public float xp;
        public int kills, deaths;

        public float stunT, slowT, invulnT, hurtT, shield, shieldT, thornT, calmT;
        public float atkAnim, castAnim, hurtAnim, dieT, respawnT;
        public float walkT;
        public bool moving;
        public bool isPlayer;
        public float aiThink;
        public Unit aiTarget;
        public int laneIndex;        // 小兵沿兵线走
        public int laneTarget;

        public SkillDef[] skills;
        public float[] cds;

        public bool alive => hp > 0f;
        public Vector3 HeadPos => pos + Vector3.up * (height + 26f);
    }

    public class Projectile
    {
        public Vector3 pos, dir;
        public Team team;
        public Unit src;
        public float speed, dmg, life, size, slow, splash, splashRadius;
        public int pierce;
        public bool alive = true;
        public Color color;
        public bool bubble;
        public GameObject go;
        public int hitMask;   // 已命中过谁用 uid 位判断不必要，简单起见只穿透不重复
        public HashSet<int> hit = new HashSet<int>();
    }

    public class Zone
    {
        public Vector3 pos;
        public float r, life, t, slow;
        public Team team;
        public Color color;
    }

    /// <summary>
    /// 战场规则：3v3、兵线、塔与水晶保护、技能、AI、终极对决。
    /// 数值与 Web 版一致（技能表见 HeroDefs.cs）。
    /// </summary>
    public class Arena : MonoBehaviour
    {
        public static Arena I;

        public const float MapW = 3000f, MapH = 1600f;
        public const float SuddenDeathTime = 240f;   // 4:00 终极对决
        public const float RespawnTime = 5.5f;
        public const float WaveInterval = 18f;
        public const float XpToLevel2 = 260f;

        public readonly List<Unit> units = new List<Unit>();
        public readonly List<Unit> heroes = new List<Unit>();
        public readonly List<Unit> minions = new List<Unit>();
        public readonly List<Projectile> shots = new List<Projectile>();
        public readonly List<Zone> zones = new List<Zone>();
        public readonly List<Unit> towersBlue = new List<Unit>();
        public readonly List<Unit> towersRed = new List<Unit>();
        public Unit baseBlue, baseRed;
        public Unit player;
        public Team winner = Team.Neutral;
        public float clock, waveT;
        public bool over, started, suddenDeath;
        public int scoreBlue, scoreRed;

        /* 兵线拉直：镜头朝 +Z，孩子只要按“右”就能一路推过去 */
        public static readonly Vector3[] Lane =
        {
            new Vector3(300f, 0f, 800f),
            new Vector3(760f, 0f, 800f),
            new Vector3(1180f, 0f, 800f),
            new Vector3(1500f, 0f, 800f),
            new Vector3(1900f, 0f, 800f),
            new Vector3(2320f, 0f, 800f),
            new Vector3(2700f, 0f, 800f),
        };

        int _uid;
        System.Random _rng = new System.Random(20261101);
        float Rand(float a, float b) => a + (float)_rng.NextDouble() * (b - a);
        static float Rng(float a, float b) => Random.Range(a, b);

        public static Arena Create(HeroId playerHero, Transform parent)
        {
            var go = new GameObject("Arena");
            go.transform.SetParent(parent, false);
            var a = go.AddComponent<Arena>();
            I = a;
            a.Setup(playerHero);
            return a;
        }

        void Setup(HeroId playerHero)
        {
            /* 玩家 + 2 名随机队友 vs 其余 3 位（6 位英雄每局都登场） */
            var others = new List<HeroId>();
            foreach (var d in HeroDef.All) if (d.id != playerHero) others.Add(d.id);
            for (int i = others.Count - 1; i > 0; i--)
            {
                int j = _rng.Next(i + 1);
                (others[i], others[j]) = (others[j], others[i]);
            }

            baseBlue = MakeBase(Team.Blue, new Vector3(230f, 0f, 800f));
            baseRed = MakeBase(Team.Red, new Vector3(2770f, 0f, 800f));

            towersBlue.Add(MakeTower(Team.Blue, 0, new Vector3(760f, 0f, 800f)));
            towersBlue.Add(MakeTower(Team.Blue, 1, new Vector3(1180f, 0f, 800f)));
            towersRed.Add(MakeTower(Team.Red, 0, new Vector3(1900f, 0f, 800f)));
            towersRed.Add(MakeTower(Team.Red, 1, new Vector3(2320f, 0f, 800f)));

            /* 阵容别随机出三脆皮：两队都保证一名前排，玩家队再优先配一个辅助/远程 */
            var allies = new List<HeroId>(2);
            bool playerFront = playerHero == HeroId.Tiger || playerHero == HeroId.Bear;
            if (!playerFront)
            {
                allies.Add(TakePreferred(others, HeroId.Bear, HeroId.Tiger));
                allies.Add(TakePreferred(others, HeroId.Rabbit, HeroId.Otter, HeroId.Hedgehog, HeroId.Fox));
            }
            else
            {
                allies.Add(TakePreferred(others, HeroId.Hedgehog, HeroId.Fox, HeroId.Rabbit, HeroId.Otter));
                allies.Add(TakePreferred(others, HeroId.Rabbit, HeroId.Otter, HeroId.Fox, HeroId.Hedgehog));
            }

            var blueIds = new List<HeroId> { playerHero, allies[0], allies[1] };
            var redIds = new List<HeroId>(others);   // 剩下三人就是对面，仍有至少一个前排
            for (int i = 0; i < 3; i++)
            {
                var h = MakeHero(blueIds[i], Team.Blue, i);
                h.isPlayer = i == 0;
                if (h.isPlayer) player = h;
            }
            for (int i = 0; i < 3; i++) MakeHero(redIds[i], Team.Red, i);

            started = true;
            waveT = 3f;
            Fx.Banner("先拆掉两座蘑菇塔，再点亮敌方水晶！", 3.4f);
        }

        Unit NewUnit(UnitKind kind, Team team, string name, Vector3 pos)
        {
            var u = new Unit { uid = _uid++, kind = kind, team = team, name = name, pos = pos };
            u.cds = new float[3];      // 塔和基地也要有，StepUnit 会统一走冷却
            units.Add(u);
            return u;
        }

        Unit MakeBase(Team team, Vector3 pos)
        {
            var u = NewUnit(UnitKind.Base, team, team == Team.Blue ? "清清水晶" : "红红水晶", pos);
            u.hp = u.maxHp = 4200f;
            u.radius = 90f; u.height = 150f; u.range = 400f; u.dmg = 120f;
            u.atkInterval = 1.0f; u.atkTimer = 1f;
            return u;
        }

        Unit MakeTower(Team team, int tier, Vector3 pos)
        {
            var u = NewUnit(UnitKind.Tower, team, tier == 0 ? "外塔" : "内塔", pos);
            u.hp = u.maxHp = 4200f;
            u.radius = 58f; u.height = 140f;
            u.range = 350f; u.dmg = 100f; u.atkInterval = 1.0f; u.atkTimer = Rand(0f, 1f);
            u.level = tier;
            return u;
        }

        Unit MakeHero(HeroId id, Team team, int slot)
        {
            var d = HeroDef.Get(id);
            /* 往兵线方向让出一点身位，镜头里水晶在身后而不是糊在脸上 */
            var u = NewUnit(UnitKind.Hero, team, d.name,
                BasePos(team) + new Vector3(team == Team.Blue ? 150f : -150f, 0f, (slot - 1) * 70f));
            u.def = d; u.heroId = id; u.skills = d.skills;
            u.maxHp = u.hp = d.hp;
            u.dmg = d.dmg; u.range = d.range; u.atkInterval = d.atkInterval;
            u.moveSpeed = d.moveSpeed; u.radius = d.radius; u.height = d.height;
            u.cds = new float[3];
            u.atkTimer = 0.2f;
            u.laneIndex = team == Team.Blue ? 0 : Lane.Length - 1;
            u.laneTarget = team == Team.Blue ? 1 : Lane.Length - 2;
            heroes.Add(u);
            return u;
        }

        public Vector3 BasePos(Team t) => t == Team.Blue ? baseBlue.pos : baseRed.pos;

        static HeroId TakePreferred(List<HeroId> pool, params HeroId[] prefs)
        {
            foreach (var p in prefs)
                if (pool.Contains(p)) { pool.Remove(p); return p; }
            var fallback = pool[0];
            pool.RemoveAt(0);
            return fallback;
        }

        /* ================= 主循环 ================= */
        void Update()
        {
            if (!started || over || Boot.Paused) return;
            float dt = Time.deltaTime;
            clock += dt;

            if (!suddenDeath && clock >= SuddenDeathTime)
            {
                suddenDeath = true;
                Fx.Banner("终极对决！水晶护盾全部消失", 3.2f);
                Sfx.Play("ult");
            }

            waveT -= dt;
            if (waveT <= 0f) { waveT = WaveInterval; SpawnWave(Team.Blue); SpawnWave(Team.Red); }

            for (int i = 0; i < units.Count; i++) StepUnit(units[i], dt);
            for (int i = 0; i < heroes.Count; i++)
                if (heroes[i].alive) AddXp(heroes[i], 2f * dt);

            /* 兜底：5 分钟按水晶剩余血量判定，绝不让一局无限拖下去 */
            if (!over && clock >= 300f)
            {
                float b = baseBlue.hp / baseBlue.maxHp, r = baseRed.hp / baseRed.maxHp;
                if (Mathf.Abs(b - r) < 0.01f) EndMatch(scoreBlue >= scoreRed ? Team.Blue : Team.Red);
                else EndMatch(b > r ? Team.Blue : Team.Red);
                Fx.Banner("时间到！按水晶血量判定", 4f);
                return;
            }
            StepProjectiles(dt);
            StepZones(dt);
            CleanupDead();

            if (baseBlue.hp <= 0f && !over) EndMatch(Team.Red);
            else if (baseRed.hp <= 0f && !over) EndMatch(Team.Blue);
        }

        void SpawnWave(Team team)
        {
            Vector3 origin = BasePos(team);
            for (int k = 0; k < 3; k++)
            {
                var m = NewUnit(UnitKind.Minion, team, "小果冻", origin + new Vector3(0f, 0f, (k - 1) * 46f));
                m.hp = m.maxHp = 280f;
                m.radius = 20f; m.height = 46f; m.range = 118f; m.dmg = 22f;
                m.atkInterval = 0.9f; m.atkTimer = Rand(0f, 0.6f); m.moveSpeed = 176f;
                m.laneIndex = team == Team.Blue ? 1 : Lane.Length - 2;
                m.laneTarget = m.laneIndex;
                minions.Add(m);
            }
        }

        void StepUnit(Unit u, float dt)
        {
            u.atkAnim = Mathf.Max(0f, u.atkAnim - dt);
            u.castAnim = Mathf.Max(0f, u.castAnim - dt);
            u.hurtAnim = Mathf.Max(0f, u.hurtAnim - dt);
            u.stunT = Mathf.Max(0f, u.stunT - dt);
            u.slowT = Mathf.Max(0f, u.slowT - dt);
            u.invulnT = Mathf.Max(0f, u.invulnT - dt);
            u.shieldT = Mathf.Max(0f, u.shieldT - dt);
            u.thornT = Mathf.Max(0f, u.thornT - dt);
            if (u.shieldT <= 0f) u.shield = 0f;

            for (int i = 0; i < u.cds.Length; i++) u.cds[i] = Mathf.Max(0f, u.cds[i] - dt);
            u.calmT += dt;

            if (!u.alive)
            {
                if (u.kind == UnitKind.Hero)
                {
                    u.dieT += dt;
                    u.respawnT -= dt;
                    if (u.respawnT <= 0f) Respawn(u);
                }
                return;
            }

            u.atkTimer -= dt;

            /* 脱战 5 秒后缓慢回血，孩子被塔打残了不用一直回城 */
            if (u.kind == UnitKind.Hero && u.calmT > 5f && u.hp < u.maxHp)
                u.hp = Mathf.Min(u.maxHp, u.hp + u.maxHp * 0.015f * dt);

            if (u.stunT > 0f) { u.moving = false; return; }

            switch (u.kind)
            {
                case UnitKind.Hero: StepHero(u, dt); break;
                case UnitKind.Minion: StepMinion(u, dt); break;
                case UnitKind.Tower:
                case UnitKind.Base: StepStructure(u); break;
            }
        }

        void StepHero(Unit h, float dt)
        {
            if (h.isPlayer)
            {
                /* 玩家移动由 InputHub 写入 moveDir（Hud 读取摇杆/键盘） */
                Vector3 dir = InputHub.Move;
                h.moving = dir.sqrMagnitude > 0.01f;
                if (h.moving)
                {
                    dir.Normalize();
                    h.moveDir = dir;
                    h.facing = dir.x >= 0f ? 1f : -1f;
                    MoveTo(h, h.pos + dir * (h.moveSpeed * (h.slowT > 0f ? 0.55f : 1f) * dt));
                    if (h.walkT == 0f) h.walkT = 0.01f;
                    h.walkT += dt;
                }
                for (int i = 0; i < 3; i++)
                    if (InputHub.SkillPressed(i)) TryCast(h, i);
            }
            else StepHeroAI(h, dt);

            /* 自动攻击最近的敌人 */
            var target = NearestEnemy(h, h.range + h.radius);
            if (target != null && h.atkTimer <= 0f)
            {
                h.atkTimer = h.atkInterval;
                h.atkAnim = 0.34f;
                h.facing = target.pos.x >= h.pos.x ? 1f : -1f;
                if (h.range > 250f) Shoot(h, target.pos - h.pos, h.dmg, h.def != null ? h.def.accent : Color.white, 700f, 0f, 0f, 0f, 0);
                else HitWithFx(target, h.dmg, h, 0);
            }
        }

        void StepHeroAI(Unit h, float dt)
        {
            float hpP = h.hp / h.maxHp;
            bool retreat = hpP < 0.3f;

            /* 每 0.2~0.3 秒做一次决策；以前是每帧 5% 掷骰，技能会瞬间全丢 */
            h.aiThink -= dt;
            bool think = h.aiThink <= 0f;
            if (think) h.aiThink = 0.22f + (h.uid % 5) * 0.025f;
            if (h.aiTarget == null || !h.aiTarget.alive) h.aiTarget = AiTarget(h);
            var t = h.aiTarget;

            if (think) StepHeroSkills(h, hpP, retreat);

            /* 走位：近战贴身、远程保持射程，血少回撤 */
            if (retreat)
            {
                Vector3 home = BasePos(h.team) + new Vector3(h.team == Team.Blue ? 70f : -70f, 0f, 0f);
                Vector3 away = home - h.pos;
                if (away.magnitude > 55f) MoveAI(h, away, dt, 1f);
                else h.moving = false;
                h.facing = away.x >= 0f ? 1f : -1f;
                return;
            }

            if (t == null)
            {
                Vector3 goal = Lane[h.team == Team.Blue ? Lane.Length - 1 : 0];
                MoveAI(h, goal - h.pos, dt, 0.9f);
                return;
            }

            Vector3 toT = t.pos - h.pos;
            float dist = toT.magnitude;
            h.facing = toT.x >= 0f ? 1f : -1f;

            if (h.range > 250f)
            {
                /* 远程：太近就后撤，太远就靠近，射程内小幅横移 */
                if (dist < h.range * 0.55f)
                    MoveAI(h, -toT, dt, 1f);
                else if (dist > h.range * 0.86f)
                    MoveAI(h, toT, dt, 0.9f);
                else
                {
                    Vector3 side = Vector3.Cross(Vector3.up, toT.normalized) * ((h.uid & 1) == 0 ? 1f : -1f);
                    MoveAI(h, side, dt, 0.35f);
                }
            }
            else
            {
                float keep = h.range * 0.84f;
                if (dist > keep) MoveAI(h, toT, dt, 1f);
                else h.moving = false;
            }
        }

        void MoveAI(Unit h, Vector3 dir, float dt, float speedK)
        {
            if (dir.sqrMagnitude < 0.0001f) { h.moving = false; return; }
            dir.y = 0f;
            dir.Normalize();
            h.moveDir = dir;
            h.moving = true;
            MoveTo(h, h.pos + dir * (h.moveSpeed * speedK * (h.slowT > 0f ? 0.55f : 1f) * dt));
            h.walkT += dt;
        }

        void StepHeroSkills(Unit h, float hpP, bool retreat)
        {
            for (int i = 0; i < 3; i++)
            {
                var s = h.skills[i];
                if (s.unlockAt2 && h.level < 2) continue;
                if (h.cds[i] > 0f) continue;

                bool support = s.kind == SkillKind.Heal || s.kind == SkillKind.Shield;
                if (retreat && !support) continue;

                bool use = false;
                switch (s.kind)
                {
                    case SkillKind.Heal:
                        use = LowAlly(h, s.radius, 0.68f) && Random.value < 0.55f;
                        break;
                    case SkillKind.Shield:
                        use = hpP < 0.75f && EnemyHeroNear(h, 420f) && Random.value < 0.5f;
                        break;
                    case SkillKind.Dash:
                    {
                        var t = h.aiTarget;
                        if (t != null)
                        {
                            float d = Vector3.Distance(h.pos, t.pos);
                            use = d > s.range * 0.9f && d < s.range * 1.7f && Random.value < 0.4f;
                        }
                        break;
                    }
                    case SkillKind.Cone:
                        use = CountEnemiesAround(h, s.range, 0.2f) > 0 && Random.value < 0.5f;
                        break;
                    case SkillKind.Pull:
                    case SkillKind.Leap:
                        use = NearestHero(h, s.range) != null && Random.value < 0.32f;
                        break;
                    case SkillKind.Multi:
                        use = NearestEnemy(h, s.range) != null && Random.value < 0.34f;
                        break;
                    case SkillKind.Radial:
                        use = NearestEnemy(h, s.range) != null && Random.value < 0.42f;
                        break;
                    case SkillKind.Aoe:
                        use = CountEnemiesAround(h, s.radius, -1f) > 0 && Random.value < 0.42f;
                        break;
                    default:
                        use = NearestEnemy(h, Mathf.Max(s.range, h.range)) != null && Random.value < 0.36f;
                        break;
                }
                if (use) { TryCast(h, i); break; }   // 一次思考只放一个技能
            }
        }

        bool LowAlly(Unit h, float radius, float pct)
        {
            foreach (var a in heroes)
            {
                if (!a.alive || a.team != h.team) continue;
                if (a.hp / a.maxHp < pct && Vector3.Distance(a.pos, h.pos) <= radius) return true;
            }
            return false;
        }

        bool EnemyHeroNear(Unit h, float radius)
        {
            foreach (var o in heroes)
                if (o.alive && o.team != h.team && Vector3.Distance(o.pos, h.pos) <= radius) return true;
            return false;
        }

        int CountEnemiesAround(Unit h, float radius, float dotMin)
        {
            int n = 0;
            Vector3 aim = h.moveDir.sqrMagnitude > 0.01f ? h.moveDir.normalized : new Vector3(h.facing, 0f, 0f);
            foreach (var u in units)
            {
                if (!u.alive || u.team == h.team) continue;
                Vector3 to = u.pos - h.pos;
                if (to.magnitude > radius + u.radius) continue;
                if (dotMin < 0.99f && Vector3.Dot(to.normalized, aim) < dotMin) continue;
                n++;
            }
            return n;
        }

        Unit AiTarget(Unit h)
        {
            Unit best = null;
            float bd = 900f;
            foreach (var o in units)
            {
                if (!o.alive || o.team == h.team) continue;
                if (o.kind == UnitKind.Tower && IsTowerProtected(o)) continue;
                if (o.kind == UnitKind.Base && IsBaseProtected(o)) continue;
                float d = Vector3.Distance(h.pos, o.pos);
                float w = d + (o.kind == UnitKind.Hero ? -40f : 0f);
                if (suddenDeath && o.kind == UnitKind.Base) w -= 1200f;
                if (w < bd) { bd = w; best = o; }
            }
            return best;
        }

        void StepMinion(Unit m, float dt)
        {
            var foe = NearestEnemy(m, m.range + 40f);
            if (foe != null)
            {
                m.moving = false;
                m.facing = foe.pos.x >= m.pos.x ? 1f : -1f;
                if (m.atkTimer <= 0f)
                {
                    m.atkTimer = m.atkInterval;
                    m.atkAnim = 0.22f;
                    /* 小兵对塔/水晶有攻城加成，保证兵线真的能推塔 */
                    float dmg = (foe.kind == UnitKind.Tower || foe.kind == UnitKind.Base) ? m.dmg * 2.0f : m.dmg;
                    HitWithFx(foe, dmg, m, 0);
                }
                return;
            }

            /* 沿兵线走：到达当前路点才推进，不能每帧把索引往后跳 */
            int stepDir = m.team == Team.Blue ? 1 : -1;
            int idx = Mathf.Clamp(m.laneIndex, 0, Lane.Length - 1);
            Vector3 goal = Lane[idx];
            for (int guard = 0; guard < Lane.Length; guard++)
            {
                if ((goal - m.pos).sqrMagnitude > 70f * 70f) break;
                int nextIdx = idx + stepDir;
                if (nextIdx < 0 || nextIdx >= Lane.Length) break;
                idx = nextIdx;
                goal = Lane[idx];
            }
            m.laneIndex = idx;
            Vector3 to = goal - m.pos;
            float d = to.magnitude;
            if (d < 10f) return;
            to /= d;
            m.moveDir = to;
            m.facing = to.x >= 0f ? 1f : -1f;
            m.moving = true;
            MoveTo(m, m.pos + to * (m.moveSpeed * (m.slowT > 0f ? 0.55f : 1f) * dt));
            m.walkT += dt;
        }

        void StepStructure(Unit s)
        {
            var target = NearestEnemy(s, s.range);
            if (target == null) return;
            if (s.atkTimer > 0f) return;
            s.atkTimer = s.atkInterval;
            s.atkAnim = 0.32f;
            /* 塔用飞弹，水晶用光柱 */
            Shoot(s, target.pos - s.pos, s.dmg,
                s.kind == UnitKind.Base ? new Color(0.6f, 0.9f, 1f) : new Color(1f, 0.86f, 0.6f),
                s.kind == UnitKind.Base ? 900f : 760f, 0f, 0f, 0f, 0);
        }

        void MoveTo(Unit u, Vector3 p)
        {
            p.x = Mathf.Clamp(p.x, 60f, MapW - 60f);
            p.z = Mathf.Clamp(p.z, 60f, MapH - 60f);
            p.y = 0f;
            u.pos = p;
        }

        /* ================= 投射物 ================= */
        public void Shoot(Unit src, Vector3 dir, float dmg, Color color, float speed,
            float slow, float splash, float splashRadius, int pierce)
        {
            if (dir.sqrMagnitude < 0.001f) dir = Vector3.right;
            dir.y = 0f;
            var p = new Projectile
            {
                pos = src.pos + Vector3.up * (src.height * 0.45f),
                dir = dir.normalized,
                team = src.team,
                src = src,
                speed = speed,
                dmg = dmg,
                life = 1.6f,
                size = splash > 0f ? 9f : 6f,
                color = color,
                slow = slow,
                splash = splash,
                splashRadius = splashRadius,
                pierce = pierce,
                bubble = splash > 0f,
            };
            shots.Add(p);
            Fx.Muzzle(p.pos, color);
        }

        void StepProjectiles(float dt)
        {
            for (int i = 0; i < shots.Count; i++)
            {
                var p = shots[i];
                if (!p.alive) continue;
                p.pos += p.dir * (p.speed * dt);
                p.life -= dt;
                if (p.life <= 0f) { p.alive = false; continue; }

                foreach (var u in units)
                {
                    if (!u.alive || u.team == p.team) continue;
                    if (u.kind == UnitKind.Tower || u.kind == UnitKind.Base)
                    {
                        if (Vector3.Distance(p.pos, u.pos) > u.radius * 0.7f) continue;
                    }
                    else if (Vector3.Distance(p.pos, u.pos) > u.radius + 10f) continue;
                    if (p.hit.Contains(u.uid)) continue;

                    if (p.splash > 0f)
                    {
                        p.alive = false;
                        AreaDamage(p.pos, p.splashRadius, p.dmg, p.src, p.team, p.slow, 0f, 0f);
                        Fx.Burst(p.pos, p.color, 14);
                        Fx.Ring(p.pos, p.splashRadius, p.color, 0.45f);
                        Sfx.Play("boom");
                    }
                    else
                    {
                        HitWithFx(u, p.dmg, p.src, 0f, p.color);
                        if (p.slow > 0f) u.slowT = Mathf.Max(u.slowT, p.slow);
                        p.hit.Add(u.uid);
                        if (p.pierce > 0) p.pierce--;
                        else { p.alive = false; }
                        Fx.Burst(p.pos, p.color, 6);
                    }
                    break;
                }
            }
            for (int i = shots.Count - 1; i >= 0; i--) if (!shots[i].alive) shots.RemoveAt(i);
        }

        /* ================= 伤害与范围 ================= */
        public void HitWithFx(Unit target, float amount, Unit src, float stun = 0f, Color? col = null)
        {
            DealDamage(target, amount, src);
            if (stun > 0f) target.stunT = Mathf.Max(target.stunT, stun);
            target.hurtAnim = 0.22f;
            target.hurtT = 0.22f;
            if (src != null && src.alive) target.facing = src.pos.x >= target.pos.x ? 1f : -1f;
            if (src != null && src.kind == UnitKind.Hero && src.range <= 260f)
                Fx.Slash(src.pos + new Vector3(src.facing * 46f, 0f, 0f), src.facing,
                    src.def != null ? src.def.accent : new Color(1f, 0.92f, 0.75f), 132f);
            Fx.Hit(target.pos + Vector3.up * (target.height * 0.55f), col ?? new Color(1f, 0.92f, 0.75f),
                src != null && src.isPlayer);
            Sfx.Play("hit");
            if (src != null && src.isPlayer && amount >= 45f && Time.timeScale > 0.5f) HitStop(0.045f);
        }

        public void DealDamage(Unit target, float amount, Unit src, bool reflect = true)
        {
            if (target == null || !target.alive) return;
            if (target.kind == UnitKind.Hero && target.invulnT > 0f) return;
            if (target.kind == UnitKind.Tower && IsTowerProtected(target)) { Fx.Text(target.pos, "先拆外塔", new Color(1f, 0.95f, 0.7f)); return; }
            if (target.kind == UnitKind.Base && IsBaseProtected(target)) { Fx.Text(target.pos, "水晶被保护着", new Color(1f, 0.95f, 0.7f)); return; }

            /* 刺球反伤：打它的人被扎回去 */
            if (reflect && target.thornT > 0f && src != null && src != target && src.alive && src.kind == UnitKind.Hero)
            {
                DealDamage(src, 24f + target.level * 5f, target, false);
                Fx.Hit(src.pos + Vector3.up * 40f, new Color(1f, 0.85f, 0.66f), false);
            }

            if (target.shield > 0f)
            {
                float absorb = Mathf.Min(target.shield, amount);
                target.shield -= absorb;
                amount -= absorb;
            }
            target.hp -= amount;
            if (amount > 0.1f) target.calmT = 0f;
            if (amount >= 1f)
                Fx.Text(target.pos + Vector3.up * (target.height + 24f), Mathf.RoundToInt(amount).ToString(),
                    target.team == Team.Blue ? new Color(1f, 0.78f, 0.72f) : new Color(1f, 1f, 0.82f));

            if (target.hp <= 0f) Kill(target, src);
        }

        void Kill(Unit target, Unit killer)
        {
            target.hp = 0f;
            target.dieT = 0f;
            Fx.Burst(target.pos + Vector3.up * (target.height * 0.5f), new Color(1f, 0.9f, 0.7f), 18);
            if (target.kind == UnitKind.Hero)
            {
                target.deaths++;
                /* 落后的一方复活快一点，别让一局在 90 秒就滚雪球滚死 */
                int behind = target.team == Team.Blue ? scoreRed - scoreBlue : scoreBlue - scoreRed;
                target.respawnT = Mathf.Max(3.8f, RespawnTime - Mathf.Clamp(behind, 0, 3) * 0.55f);
                if (killer != null) killer.kills++;
                if (killer != null && killer.kind == UnitKind.Hero) AddXp(killer, 140f);
                if (killer != null)
                    foreach (var a in heroes)
                        if (a != killer && a.alive && a.team == killer.team && Vector3.Distance(a.pos, target.pos) < 700f)
                            AddXp(a, 60f);
                if (target.team == Team.Blue) scoreRed++; else scoreBlue++;
                Fx.Banner($"{killer?.name ?? "？"} 击败了 {target.name}", 1.8f);
                Sfx.Play("ult");
            }
            else if (target.kind == UnitKind.Tower)
            {
                Fx.Banner(target.team == Team.Blue ? "我方蘑菇塔被拆了！" : "拆掉一座敌方蘑菇塔！", 2f);
                Sfx.Play("boom");
                foreach (var a in heroes)
                    if (a.alive && a.team != target.team) AddXp(a, 80f);
            }
            else if (target.kind == UnitKind.Minion)
            {
                if (killer != null && killer.kind == UnitKind.Hero) AddXp(killer, 14f);
                foreach (var a in heroes)
                    if (a != killer && a.alive && killer != null && a.team == killer.team &&
                        Vector3.Distance(a.pos, target.pos) < 450f) AddXp(a, 7f);
            }
            else if (target.kind == UnitKind.Base)
            {
                Sfx.Play("boom");
            }
        }

        void AddXp(Unit h, float add)
        {
            if (h == null || add <= 0f || h.level >= 2) return;
            h.xp += add;
            if (h.xp >= XpToLevel2)
            {
                h.level = 2;
                Fx.Text(h.pos, "二级解锁大招！", new Color(1f, 0.95f, 0.6f));
                if (h.isPlayer) { Fx.Banner("大招解锁！按右上的技能键放出来", 1.8f); Sfx.Play("ult"); }
            }
        }

        void Respawn(Unit h)
        {
            h.hp = h.maxHp;
            h.pos = BasePos(h.team) + new Vector3(h.team == Team.Blue ? 150f : -150f, 0f, 0f);
            h.invulnT = 1.6f;
            h.stunT = 0f; h.slowT = 0f; h.shield = 0f; h.thornT = 0f;
            h.moveDir = Vector3.zero;
            h.atkTimer = 0.3f;
            Fx.Ring(h.pos, 90f, h.team == Team.Blue ? new Color(0.6f, 0.95f, 1f) : new Color(1f, 0.7f, 0.6f), 0.5f);
        }

        public void AreaDamage(Vector3 center, float radius, float dmg, Unit src, Team team,
            float slow, float stun, float knock)
        {
            foreach (var u in units)
            {
                if (!u.alive || u.team == team || u.team == Team.Neutral) continue;
                if (Vector3.Distance(center, u.pos) > radius + u.radius) continue;
                DealDamage(u, dmg, src);
                if (slow > 0f) u.slowT = Mathf.Max(u.slowT, slow);
                if (stun > 0f) u.stunT = Mathf.Max(u.stunT, stun);
                if (knock > 0f && u.kind != UnitKind.Tower && u.kind != UnitKind.Base)
                {
                    Vector3 n = (u.pos - center).normalized;
                    MoveTo(u, u.pos + n * knock);
                }
            }
        }

        public Unit NearestEnemy(Unit from, float radius)
        {
            Unit best = null;
            float bd = radius;
            foreach (var u in units)
            {
                if (!u.alive || u.team == from.team) continue;
                if (u.kind == UnitKind.Tower && IsTowerProtected(u)) continue;
                if (u.kind == UnitKind.Base && IsBaseProtected(u)) continue;
                float d = Vector3.Distance(from.pos, u.pos);
                if (d <= bd) { bd = d; best = u; }
            }
            return best;
        }

        public Unit NearestHero(Unit from, float radius)
        {
            Unit best = null; float bd = radius;
            foreach (var u in heroes)
            {
                if (!u.alive || u.team == from.team) continue;
                float d = Vector3.Distance(from.pos, u.pos);
                if (d < bd) { bd = d; best = u; }
            }
            return best;
        }

        public Unit NearestAlly(Unit from, float radius, bool includeSelf)
        {
            Unit best = null; float bd = radius;
            foreach (var u in heroes)
            {
                if (!u.alive || u.team != from.team) continue;
                if (!includeSelf && u == from) continue;
                float d = Vector3.Distance(from.pos, u.pos);
                if (d < bd) { bd = d; best = u; }
            }
            return best;
        }

        public bool IsTowerProtected(Unit t)
        {
            if (suddenDeath) return false;
            if (t.kind != UnitKind.Tower) return false;
            var list = t.team == Team.Blue ? towersBlue : towersRed;
            foreach (var o in list)
                if (o != t && o.alive && o.level < t.level) return true;
            return false;
        }

        public bool IsBaseProtected(Unit b)
        {
            if (suddenDeath) return false;
            if (b.kind != UnitKind.Base) return false;
            var list = b.team == Team.Blue ? towersBlue : towersRed;
            foreach (var o in list) if (o.alive) return true;
            return false;
        }

        void StepZones(float dt)
        {
            for (int i = zones.Count - 1; i >= 0; i--)
            {
                var z = zones[i];
                z.t += dt;
                if (z.t >= z.life) { zones.RemoveAt(i); continue; }
                foreach (var u in units)
                {
                    if (!u.alive || u.team == z.team) continue;
                    if (Vector3.Distance(z.pos, u.pos) > z.r + u.radius) continue;
                    u.slowT = Mathf.Max(u.slowT, z.slow);
                }
            }
        }

        void CleanupDead()
        {
            for (int i = units.Count - 1; i >= 0; i--)
            {
                var u = units[i];
                if (u.alive) continue;
                if (u.kind == UnitKind.Hero && u.respawnT > 0f) continue;
                if (u.kind == UnitKind.Hero) continue;      // 英雄永远留在列表里等复活
                units.RemoveAt(i);
                if (u.kind == UnitKind.Minion) minions.Remove(u);
            }
        }

        void EndMatch(Team winnerTeam)
        {
            over = true;
            winner = winnerTeam;
            Fx.Banner(winnerTeam == Team.Blue ? "胜利！水晶亮起来了" : "水晶被点亮了…再来一局？", 6f);
            Sfx.Play(winnerTeam == Team.Blue ? "win" : "lose");
        }

        /* ================= 技能 ================= */
        public void TryCast(Unit h, int index)
        {
            if (!h.alive || h.stunT > 0f) return;
            var s = h.skills[index];
            if (s == null) return;
            if (s.unlockAt2 && h.level < 2) { Fx.Text(h.pos, "2 级解锁", new Color(1f, 0.9f, 0.6f)); return; }
            if (h.cds[index] > 0f) return;
            if (s.kind == SkillKind.Heal || s.kind == SkillKind.Shield)
            {
                /* 支援类不需要目标 */
            }
            h.cds[index] = s.cd;
            h.castAnim = 0.5f;
            Sfx.Play("cast");
            if (h.isPlayer && index == 2) { CameraRig.Punch(0.9f); CameraRig.Shake(4f); }
            Cast(h, s, index);
        }

        void Cast(Unit h, SkillDef s, int index)
        {
            Vector3 forward = h.moveDir.sqrMagnitude > 0.01f ? h.moveDir.normalized : new Vector3(h.facing, 0f, 0f);
            var aim = NearestEnemy(h, Mathf.Max(s.range, 260f));
            Vector3 aimDir = aim != null ? (aim.pos - h.pos).normalized : forward;
            if (aim != null) h.facing = aim.pos.x >= h.pos.x ? 1f : -1f;

            switch (s.kind)
            {
                case SkillKind.Projectile:
                case SkillKind.Radial:
                {
                    int n = Mathf.Max(1, s.count);
                    for (int k = 0; k < n; k++)
                    {
                        Vector3 dir;
                        if (s.kind == SkillKind.Radial)
                        {
                            float a = (k / (float)n) * Mathf.PI * 2f;
                            dir = new Vector3(Mathf.Cos(a), 0f, Mathf.Sin(a));
                        }
                        else if (n > 1)
                        {
                            float a = Mathf.Atan2(aimDir.z, aimDir.x) + (k - (n - 1) * 0.5f) * 0.16f;
                            dir = new Vector3(Mathf.Cos(a), 0f, Mathf.Sin(a));
                        }
                        else dir = aimDir;
                        Shoot(h, dir, s.dmg, s.color, s.speed, s.slow, 0f, 0f, s.pierce);
                    }
                    break;
                }
                case SkillKind.Splash:
                {
                    var p = new Projectile
                    {
                        pos = h.pos + Vector3.up * (h.height * 0.45f),
                        dir = aimDir,
                        team = h.team, src = h, speed = s.speed, dmg = s.dmg, life = 1.8f,
                        size = 10f, color = s.color, slow = s.slow,
                        splash = s.dmg, splashRadius = s.radius, bubble = true,
                    };
                    shots.Add(p);
                    Fx.Muzzle(p.pos, s.color);
                    break;
                }
                case SkillKind.Dash:
                {
                    Vector3 from = h.pos;
                    Vector3 to = h.pos + aimDir * s.range;
                    MoveTo(h, to);
                    h.invulnT = Mathf.Max(h.invulnT, 0.12f);
                    Fx.Trail(from + Vector3.up * 30f, h.pos + Vector3.up * 30f, s.color);
                    if (s.dmg > 0f)
                    {
                        AreaDamage(h.pos, s.radius, s.dmg, h, h.team, s.slow, 0f, s.knock);
                        Fx.Ring(h.pos, s.radius, s.color, 0.4f);
                        CameraRig.Punch(0.7f);
                    }
                    if (s.zone)
                    {
                        var z = new Zone { pos = h.pos, r = 90f, life = 2.6f, slow = 0.9f, team = h.team, color = s.color };
                        zones.Add(z);
                    }
                    break;
                }
                case SkillKind.Aoe:
                {
                    AreaDamage(h.pos, s.radius, s.dmg, h, h.team, s.slow, s.stun, s.knock);
                    Fx.Ring(h.pos, s.radius, s.color, 0.5f);
                    Fx.Burst(h.pos + Vector3.up * 30f, s.color, 16);
                    break;
                }
                case SkillKind.Cone:
                {
                    foreach (var u in units)
                    {
                        if (!u.alive || u.team == h.team) continue;
                        Vector3 to = u.pos - h.pos;
                        if (to.magnitude > s.radius + u.radius) continue;
                        if (Vector3.Dot(to.normalized, aimDir) < 0.35f) continue;
                        DealDamage(u, s.dmg, h);
                        u.slowT = Mathf.Max(u.slowT, s.slow);
                        if (s.knock > 0f && u.kind != UnitKind.Tower && u.kind != UnitKind.Base)
                            MoveTo(u, u.pos + to.normalized * s.knock);
                        Fx.Hit(u.pos + Vector3.up * 30f, s.color, true);
                    }
                    Fx.Ring(h.pos + aimDir * 70f, s.radius * 0.8f, s.color, 0.4f);
                    break;
                }
                case SkillKind.Heal:
                {
                    h.hp = Mathf.Min(h.maxHp, h.hp + h.maxHp * s.healPct);
                    Fx.Ring(h.pos, 110f, s.color, 0.6f);
                    Fx.Text(h.pos, "+" + Mathf.RoundToInt(h.maxHp * s.healPct), s.color);
                    foreach (var a in heroes)
                    {
                        if (a == h || !a.alive || a.team != h.team) continue;
                        if (Vector3.Distance(a.pos, h.pos) > s.radius) continue;
                        a.hp = Mathf.Min(a.maxHp, a.hp + a.maxHp * s.healPct * 0.7f);
                        Fx.Ring(a.pos, 80f, s.color, 0.5f);
                        Fx.Text(a.pos, "+" + Mathf.RoundToInt(a.maxHp * s.healPct * 0.7f), s.color);
                    }
                    break;
                }
                case SkillKind.Shield:
                {
                    h.shield = h.maxHp * s.shieldPct;
                    h.shieldT = s.buffT;
                    h.thornT = s.buffT;
                    Fx.Ring(h.pos, 90f, s.color, 0.6f);
                    Fx.Text(h.pos, "扎手！", s.color);
                    break;
                }
                case SkillKind.Pull:
                {
                    var t = NearestHero(h, s.range);
                    if (t == null) { Fx.Text(h.pos, "抱不到人…", s.color); h.cds[index] = 0.8f; break; }
                    Vector3 toH = h.pos + aimDir * 62f;
                    Fx.Trail(t.pos + Vector3.up * 30f, toH + Vector3.up * 30f, s.color);
                    MoveTo(t, toH);
                    t.stunT = Mathf.Max(t.stunT, s.stun);
                    DealDamage(t, s.dmg, h);
                    h.shield = Mathf.Max(h.shield, h.maxHp * s.shieldPct);
                    h.shieldT = Mathf.Max(h.shieldT, 3f);
                    Fx.Text(h.pos, "抱住了！", s.color);
                    break;
                }
                case SkillKind.Leap:
                {
                    var t = NearestHero(h, s.range);
                    Vector3 dest = t != null ? t.pos : h.pos + aimDir * 220f;
                    Vector3 from = h.pos;
                    MoveTo(h, dest);
                    Fx.Trail(from + Vector3.up * 40f, h.pos + Vector3.up * 40f, s.color);
                    LeapLand(h, dest, s);
                    break;
                }
                case SkillKind.Multi:
                {
                    var t = NearestEnemy(h, s.range);
                    Vector3 center = t != null ? t.pos : h.pos + aimDir * 200f;
                    StartCoroutine(MultiStrike(h, center, s));
                    break;
                }
            }
        }

        void LeapLand(Unit h, Vector3 dest, SkillDef s)
        {
            AreaDamage(dest, s.radius, s.dmg, h, h.team, s.slow, s.stun, 26f);
            Fx.Ring(dest, s.radius, s.color, 0.65f);
            Fx.Burst(dest + Vector3.up * 20f, s.color, 22);
            if (s.zone) zones.Add(new Zone { pos = dest, r = s.radius * 0.8f, life = 3.2f, slow = 0.5f, team = h.team, color = s.color });
            CameraRig.Shake(9f);
        }

        System.Collections.IEnumerator MultiStrike(Unit h, Vector3 center, SkillDef s)
        {
            for (int k = 0; k < s.count; k++)
            {
                if (h == null || !h.alive) yield break;
                Vector3 at = center + new Vector3(Rand(-60f, 60f), 0f, Rand(-45f, 45f));
                Fx.Ring(at, s.radius, s.color, 0.3f);
                yield return new WaitForSeconds(s.delay);
                AreaDamage(at, s.radius, s.dmg, h, h.team, s.slow, 0f, 0f);
                Fx.Burst(at + Vector3.up * 20f, s.color, 16);
                CameraRig.Shake(6f);
                if (s.healPct > 0f)
                {
                    foreach (var a in heroes)
                    {
                        if (!a.alive || a.team != h.team) continue;
                        if (Vector3.Distance(a.pos, at) > s.radius) continue;
                        a.hp = Mathf.Min(a.maxHp, a.hp + a.maxHp * s.healPct);
                        Fx.Text(a.pos, "+" + Mathf.RoundToInt(a.maxHp * s.healPct), s.color);
                    }
                }
                Sfx.Play("boom");
            }
        }

        /* Web 版里技能命中会顿帧，这里用 Time.timeScale 做一次短促停顿 */
        public void HitStop(float seconds)
        {
            StartCoroutine(HitStopRoutine(seconds));
        }

        System.Collections.IEnumerator HitStopRoutine(float seconds)
        {
            float prev = Time.timeScale;
            Time.timeScale = 0.18f;
            yield return new WaitForSecondsRealtime(seconds);
            Time.timeScale = Boot.Paused ? 0f : prev;
        }
    }
}
