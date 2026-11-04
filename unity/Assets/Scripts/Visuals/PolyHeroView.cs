using UnityEngine;

namespace TapArena
{
    /// <summary>
    /// Polyfork 四足英雄的视图：用作者自带的 Idle/Walk/Run 采样出自然步态，
    /// 再叠加咬击、施法抬身、受击挤压、阵亡侧倒、耳朵/尾巴小动作。
    /// </summary>
    public class PolyHeroView : MonoBehaviour
    {
        public Unit unit;
        public float yawOffset;

        Art.Rig rig;
        GameObject model;
        Transform facing, head, jaw, earL, earR, tail1, tail2, shL, shR, thL, thR;
        AnimationClip idle, walk, run;
        Material[] mats;

        float _clipT, _moveK, _lastMoveK, _squash, _lunge, _flash, _deathP, _idleT, _turnLean;
        int _stepMark, _seed;
        bool _castFx, _deathDusted;
        static readonly int FlashId = Shader.PropertyToID("_Flash");

        public static PolyHeroView Attach(Unit u, Art.Rig rig)
        {
            var v = rig.root.gameObject.AddComponent<PolyHeroView>();
            v.unit = u;
            v.rig = rig;
            v.model = rig.polyModel;
            v.facing = rig.polyFacing;
            v.head = rig.head;
            v.jaw = Find(rig.head, "Jaw");
            v.earL = rig.earL;
            v.earR = rig.earR;
            v.tail1 = rig.tail1;
            v.tail2 = rig.tail2;
            v.shL = rig.shL;
            v.shR = rig.shR;
            v.thL = rig.thL;
            v.thR = rig.thR;
            v.idle = rig.polyIdle;
            v.walk = rig.polyWalk;
            v.run = rig.polyRun;
            v.mats = rig.mats;
            v._seed = (u != null ? u.uid * 37 : 11) % 90;
            v._idleT = v._seed * 0.7f;
            v._clipT = v._seed * 0.03f;
            return v;
        }

        static Transform Find(Transform root, string name)
        {
            if (root == null) return null;
            if (root.name == name) return root;
            for (int i = 0; i < root.childCount; i++)
            {
                var hit = Find(root.GetChild(i), name);
                if (hit != null) return hit;
            }
            return null;
        }

        void Update()
        {
            if (unit == null || rig == null || model == null) return;
            float dt = Time.deltaTime;
            _idleT += dt;

            float h = rig.height;
            float yaw = transform.eulerAngles.y;
            float wantYaw = (unit.facing >= 0f ? 0f : 180f) + yawOffset;
            float nextYaw = Mathf.LerpAngle(yaw, wantYaw, 1f - Mathf.Exp(-12f * dt));
            float yawDelta = Mathf.DeltaAngle(yaw, nextYaw);
            _turnLean = Mathf.Lerp(_turnLean, Mathf.Clamp(yawDelta * 2.2f, -10f, 10f),
                1f - Mathf.Exp(-10f * dt));
            transform.rotation = Quaternion.Euler(0f, nextYaw, 0f);

            if (!unit.alive)
            {
                _deathP = Mathf.Min(1f, _deathP + dt * 1.6f);
                float tip = Mathf.SmoothStep(0f, 1f, _deathP);
                transform.rotation = Quaternion.Euler(0f, nextYaw, -tip * 74f - Mathf.Sin(tip * Mathf.PI) * 5f);
                transform.position = new Vector3(unit.pos.x, transform.position.y - dt * 12f, unit.pos.z);
                transform.localScale = Vector3.one;
                if (!_deathDusted && _deathP > 0.45f)
                {
                    _deathDusted = true;
                    Fx.Dust(new Vector3(unit.pos.x, 0f, unit.pos.z), new Color(0.78f, 0.74f, 0.58f, 0.55f));
                }
                _flash = Mathf.Lerp(_flash, 1f, dt * 4f);
                ApplyFlash(_flash);
                return;
            }

            if (_deathDusted) _deathDusted = false;
            if (_deathP > 0f)
            {
                _deathP = Mathf.Max(0f, _deathP - dt * 3.4f);
                transform.rotation = Quaternion.Euler(0f, nextYaw, -_deathP * 74f);
            }

            bool moving = unit.moving;
            _moveK = Mathf.Lerp(_moveK, moving ? 1f : 0f, 1f - Mathf.Exp(-9f * dt));

            float atk = unit.atkAnim > 0f ? Mathf.Clamp01(1f - unit.atkAnim / 0.34f) : 0f;
            float cast = unit.castAnim > 0f ? Mathf.Clamp01(1f - unit.castAnim / 0.5f) : 0f;
            float hurt = unit.hurtAnim > 0f ? unit.hurtAnim / 0.22f : 0f;
            float atkArc = Mathf.Sin(atk * Mathf.PI);
            float castArc = Mathf.Sin(cast * Mathf.PI);
            float breath = Mathf.Sin(Time.time * 1.5f + _seed);
            float idleWave = Mathf.Sin(_idleT * 0.85f + _seed * 0.3f);

            /* ---- 采样作者动画：站立 Idle / 移动 Walk ---- */
            AnimationClip clip = idle;
            if (moving && walk != null) clip = walk;
            if (clip != null)
            {
                float rate = moving ? Mathf.Lerp(0.9f, 1.35f, Mathf.InverseLerp(180f, 320f, unit.moveSpeed)) : 0.55f;
                _clipT += dt * rate;
                clip.SampleAnimation(model, _clipT % Mathf.Max(0.01f, clip.length));
            }

            /* ---- 整体挤压 + 攻击前冲（四足用较小幅度） ---- */
            float squashTarget = hurt * 0.05f + atkArc * 0.02f;
            if (_moveK < 0.2f && _lastMoveK > 0.55f) squashTarget = Mathf.Max(squashTarget, 0.04f);
            _squash = Mathf.Lerp(_squash, squashTarget, 1f - Mathf.Exp(-24f * dt));
            transform.localScale = new Vector3(1f + _squash * 0.4f, 1f - _squash, 1f + _squash * 0.4f);
            float lungeWant = atk > 0f ? Mathf.Sin(Mathf.Clamp01((atk - 0.20f) / 0.58f) * Mathf.PI) * h * 0.045f : 0f;
            _lunge = Mathf.Lerp(_lunge, lungeWant, 1f - Mathf.Exp(-24f * dt));
            transform.position = new Vector3(unit.pos.x, unit.pos.y, unit.pos.z) + transform.right * _lunge;

            /* ---- 施法抬前身；平时回正 ---- */
            if (facing != null)
                facing.localRotation = Quaternion.Euler(0f, 90f, 0f) *
                                        Quaternion.Euler(0f, 0f, castArc * 9f - _turnLean * 0.25f);

            /* ---- 头部咬击 / 施法抬头 / 受击后仰；耳朵与尾巴小动作 ---- */
            if (head != null)
                head.localRotation = head.localRotation * Quaternion.Euler(
                    -atkArc * 16f - castArc * 8f + hurt * 5f + idleWave * 1.2f,
                    idleWave * 2.0f + _turnLean * 0.2f,
                    0f);
            if (jaw != null)
                jaw.localRotation = jaw.localRotation * Quaternion.Euler(atkArc * 16f + castArc * 12f, 0f, 0f);
            if (shL != null)
                shL.localRotation = shL.localRotation * Quaternion.Euler(-atkArc * 22f - castArc * 6f, 0f, 0f);
            if (shR != null)
                shR.localRotation = shR.localRotation * Quaternion.Euler(-atkArc * 14f - castArc * 4f, 0f, 0f);
            if (thL != null)
                thL.localRotation = thL.localRotation * Quaternion.Euler(-atkArc * 6f, 0f, 0f);
            if (thR != null)
                thR.localRotation = thR.localRotation * Quaternion.Euler(-atkArc * 4f, 0f, 0f);

            float tailWag = Mathf.Sin(Time.time * (2.0f + _moveK * 1.3f) + _seed * 0.1f);
            if (tail1 != null)
                tail1.localRotation = tail1.localRotation * Quaternion.Euler(0f, tailWag * 7f + idleWave * 2f, 0f);
            if (tail2 != null)
                tail2.localRotation = tail2.localRotation * Quaternion.Euler(0f, tailWag * 9f, 0f);
            float twitch = Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Time.time * 0.9f + _seed * 0.7f)), 16f) * 11f;
            if (earL != null)
                earL.localRotation = earL.localRotation * Quaternion.Euler(twitch, 0f, 0f);
            if (earR != null)
                earR.localRotation = earR.localRotation * Quaternion.Euler(twitch * 0.7f, 0f, 0f);

            /* ---- 脚步扬尘 ---- */
            float cycle = walk != null ? walk.length * 0.5f : 0.5f;
            int step = Mathf.FloorToInt(_clipT / Mathf.Max(0.05f, cycle));
            if (step != _stepMark)
            {
                _stepMark = step;
                if (_moveK > 0.35f && unit.isPlayer)
                {
                    var foot = (step & 1) == 0 ? rig.anL : rig.anR;
                    if (foot != null)
                        Fx.Dust(new Vector3(foot.position.x, 0f, foot.position.z),
                            new Color(0.80f, 0.77f, 0.60f, 0.5f));
                }
            }
            _lastMoveK = _moveK;

            /* ---- 施法起手的一小簇光：从嘴/头前方出来 ---- */
            if (unit.castAnim > 0f && !_castFx)
            {
                _castFx = true;
                Vector3 cp = rig.weapon != null ? rig.weapon.position : transform.position + Vector3.up * h * 0.8f;
                Fx.Muzzle(cp, unit.def != null ? unit.def.accent : Color.white);
            }
            if (unit.castAnim <= 0f) _castFx = false;

            _flash = Mathf.Lerp(_flash, hurt, 1f - Mathf.Exp(-20f * dt));
            ApplyFlash(_flash);
        }

        void ApplyFlash(float f)
        {
            f = Mathf.Clamp01(f * 0.8f);
            if (mats == null) return;
            for (int i = 0; i < mats.Length; i++)
                if (mats[i] != null && mats[i].HasProperty(FlashId))
                    mats[i].SetFloat(FlashId, f);
        }
    }
}
