using UnityEngine;

namespace TapArena
{
    public enum HeroId { Tiger, Fox, Rabbit, Bear, Otter, Hedgehog }
    public enum Team { Blue, Red, Neutral }
    public enum UnitKind { Hero, Minion, Tower, Base }

    /// <summary>技能类型。参数都塞在 SkillDef 里，规则集中在 Arena.CastSkill 一处实现。</summary>
    public enum SkillKind { Projectile, Splash, Dash, Aoe, Cone, Heal, Shield, Pull, Leap, Multi, Radial }

    public class SkillDef
    {
        public string name;
        public string hint;
        public SkillKind kind;
        public float cd = 6f;
        public float dmg = 60f;
        public float radius = 120f;
        public float speed = 620f;
        public float slow = 0f;
        public float stun = 0f;
        public float knock = 0f;
        public float healPct = 0f;
        public float shieldPct = 0f;
        public float range = 300f;
        public float delay = 0f;
        public int count = 1;
        public int pierce = 0;
        public float buffT = 0f;
        public Color color = new Color(1f, 0.85f, 0.5f);
        public bool unlockAt2 = false;
        public bool isDash = false;
        public bool zone = false;
    }

    public class HeroDef
    {
        public HeroId id;
        public string name;
        public string title;
        public string role;
        public float hp = 900f;
        public float dmg = 45f;
        public float range = 120f;
        public float atkInterval = 0.7f;
        public float moveSpeed = 260f;
        public float radius = 34f;
        public float height = 74f;
        public int difficulty = 1;
        public Color fur = new Color(0.95f, 0.66f, 0.31f);
        public Color dark = new Color(0.78f, 0.47f, 0.18f);
        public Color cream = new Color(1f, 0.96f, 0.9f);
        public Color accent = new Color(0.18f, 0.55f, 0.42f);
        public SkillDef[] skills = new SkillDef[3];

        static Color C(string hex)
        {
            ColorUtility.TryParseHtmlString(hex, out var c);
            return c;
        }

        static SkillDef S(string n, string hint, SkillKind k, float cd, float dmg, float radius,
            Color color, System.Action<SkillDef> tweak = null)
        {
            var s = new SkillDef { name = n, hint = hint, kind = k, cd = cd, dmg = dmg, radius = radius, color = color };
            tweak?.Invoke(s);
            return s;
        }

        public static readonly HeroDef[] All =
        {
            new HeroDef
            {
                id = HeroId.Tiger, name = "阿虎", title = "勇敢小虎", role = "战士",
                hp = 1080f, dmg = 44f, range = 125f, atkInterval = 0.62f, moveSpeed = 268f,
                radius = 34f, height = 76f, difficulty = 1,
                fur = C("#F2A94F"), dark = C("#C9752F"), cream = C("#FFF3E2"), accent = C("#2E8B6F"),
                skills = new[]
                {
                    S("猛虎冲撞", "往前冲一段，撞到的敌人受伤", SkillKind.Dash, 6.5f, 85f, 130f, C("#FFD98A"),
                        s => { s.range = 232f; s.knock = 24f; s.isDash = true; s.speed = 900f; }),
                    S("勇气咆哮", "身边一圈敌人减速", SkillKind.Aoe, 9f, 62f, 176f, C("#FFC46B"),
                        s => { s.slow = 1.3f; }),
                    S("旋风爪", "原地旋一圈，周围敌人重创", SkillKind.Aoe, 22f, 152f, 205f, C("#FFB74D"),
                        s => { s.unlockAt2 = true; s.knock = 30f; s.stun = 0.35f; }),
                }
            },
            new HeroDef
            {
                id = HeroId.Fox, name = "灵灵", title = "星星小巫", role = "法师",
                hp = 820f, dmg = 52f, range = 520f, atkInterval = 0.85f, moveSpeed = 248f,
                radius = 30f, height = 72f, difficulty = 2,
                fur = C("#E9A24C"), dark = C("#B5713A"), cream = C("#FFF6EC"), accent = C("#7B54C7"),
                skills = new[]
                {
                    S("星光火球", "丢一颗会炸开的星星", SkillKind.Splash, 5.5f, 78f, 96f, C("#C9A6FF"),
                        s => { s.speed = 660f; s.range = 560f; s.slow = 0.6f; }),
                    S("瞬光步", "闪现一段，落地炸开", SkillKind.Dash, 10f, 86f, 128f, C("#B98CFF"),
                        s => { s.range = 240f; s.slow = 0.8f; s.isDash = true; }),
                    S("星河坠落", "召唤三颗流星砸向敌人", SkillKind.Multi, 26f, 122f, 132f, C("#D6B6FF"),
                        s => { s.count = 3; s.range = 620f; s.delay = 0.42f; s.unlockAt2 = true; s.slow = 1f; }),
                }
            },
            new HeroDef
            {
                id = HeroId.Rabbit, name = "朵朵", title = "月亮小兔", role = "辅助",
                hp = 900f, dmg = 46f, range = 460f, atkInterval = 0.72f, moveSpeed = 258f,
                radius = 28f, height = 62f, difficulty = 1,
                fur = C("#FFF7F3"), dark = C("#F3D3E0"), cream = C("#FFFFFF"), accent = C("#EE8FB8"),
                skills = new[]
                {
                    S("胡萝卜星镖", "飞出去的星镖会穿透，并让敌人变慢", SkillKind.Projectile, 5f, 82f, 0f, C("#FFB7CF"),
                        s => { s.speed = 620f; s.range = 540f; s.pierce = 3; s.slow = 1.2f; }),
                    S("治愈微光", "给自己和附近队友回血", SkillKind.Heal, 15f, 0f, 380f, C("#A8F0C8"),
                        s => { s.healPct = 0.26f; }),
                    S("满月祝福", "月华范围内的队友回血、敌人受伤", SkillKind.Multi, 28f, 66f, 215f, C("#FFE7A8"),
                        s => { s.count = 2; s.delay = 0.55f; s.healPct = 0.14f; s.unlockAt2 = true; }),
                }
            },
            new HeroDef
            {
                id = HeroId.Bear, name = "阿岳", title = "森林大熊", role = "坦克",
                hp = 1420f, dmg = 58f, range = 118f, atkInterval = 0.78f, moveSpeed = 232f,
                radius = 42f, height = 92f, difficulty = 1,
                fur = C("#B98155"), dark = C("#8A5A36"), cream = C("#FBE9D2"), accent = C("#4E9A63"),
                skills = new[]
                {
                    S("荷叶拍击", "面前一片敌人被拍飞", SkillKind.Cone, 7f, 96f, 132f, C("#BFE39B"),
                        s => { s.knock = 48f; s.slow = 1.1f; s.range = 150f; }),
                    S("熊抱一下", "把最近的敌人拉进怀里抱住", SkillKind.Pull, 12f, 72f, 300f, C("#F0D2A8"),
                        s => { s.stun = 0.7f; s.shieldPct = 0.16f; s.range = 300f; }),
                    S("山崩地裂", "跳向敌人最密处砸地，留下降速裂谷", SkillKind.Leap, 30f, 168f, 235f, C("#FFD79B"),
                        s => { s.stun = 0.85f; s.range = 360f; s.unlockAt2 = true; s.zone = true; }),
                }
            },
            new HeroDef
            {
                id = HeroId.Otter, name = "泡泡", title = "溪水小獭", role = "控制",
                hp = 900f, dmg = 40f, range = 480f, atkInterval = 0.8f, moveSpeed = 268f,
                radius = 30f, height = 68f, difficulty = 2,
                fur = C("#7F9FC4"), dark = C("#5A7290"), cream = C("#F3F7FF"), accent = C("#4FA88F"),
                skills = new[]
                {
                    S("大水泡", "水泡炸开水花，减速一片", SkillKind.Splash, 5.5f, 58f, 98f, C("#BFE9FF"),
                        s => { s.speed = 620f; s.range = 500f; s.slow = 1.2f; }),
                    S("滑水冲刺", "滑过的地方留下水道", SkillKind.Dash, 11f, 40f, 90f, C("#9FDCFF"),
                        s => { s.range = 218f; s.isDash = true; s.zone = true; s.slow = 0.9f; }),
                    S("瀑布冲击", "三波水帘推挤敌人", SkillKind.Multi, 27f, 118f, 138f, C("#A8E6FF"),
                        s => { s.count = 3; s.range = 600f; s.delay = 0.4f; s.slow = 1.5f; s.unlockAt2 = true; }),
                }
            },
            new HeroDef
            {
                id = HeroId.Hedgehog, name = "尖尖", title = "星星刺猬", role = "射手",
                hp = 760f, dmg = 50f, range = 560f, atkInterval = 0.55f, moveSpeed = 258f,
                radius = 26f, height = 58f, difficulty = 3,
                fur = C("#D9B98F"), dark = C("#9C7B55"), cream = C("#FFF1DC"), accent = C("#E0604F"),
                skills = new[]
                {
                    S("三连尖刺", "扇形射出三根尖刺", SkillKind.Projectile, 4.5f, 46f, 0f, C("#FFE0A8"),
                        s => { s.count = 3; s.speed = 680f; s.range = 560f; s.pierce = 1; }),
                    S("缩成刺球", "护盾 + 反伤，谁打谁被扎", SkillKind.Shield, 14f, 0f, 0f, C("#FFD0A0"),
                        s => { s.shieldPct = 0.26f; s.slow = 1f; s.buffT = 3.5f; }),
                    S("万刺齐发", "向四周炸开尖刺", SkillKind.Radial, 26f, 52f, 152f, C("#FFD79B"),
                        s => { s.count = 12; s.speed = 560f; s.unlockAt2 = true; }),
                }
            },
        };

        public static HeroDef Get(HeroId id)
        {
            for (int i = 0; i < All.Length; i++) if (All[i].id == id) return All[i];
            return All[0];
        }
    }
}
