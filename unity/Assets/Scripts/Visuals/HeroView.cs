using UnityEngine;

namespace TapArena
{
    /// <summary>
    /// 程序化角色动画：四相步态 + 髋/胸/头分层 + 攻击/施法/受击/阵亡。
    /// 这轮补的是动画原则：待机重心、预备/出手/收势、受击挤压回弹、脚步扬尘与转向侧倾。
    /// </summary>
    public class HeroView : MonoBehaviour
    {
        public Unit unit;
        public float yawOffset;

        Art.Rig rig;
        float _phase, _moveK, _lastMoveK, _deathP, _blinkT = 2f, _faceHold, _flash;
        float _turnLean, _squash, _lunge, _idleT;
        int _blinkSeed, _stepMark;
        bool _castFx, _deathDusted;
        static readonly int FlashId = Shader.PropertyToID("_Flash");

        public static HeroView Attach(Unit u, Art.Rig rig)
        {
            var v = rig.root.gameObject.AddComponent<HeroView>();
            v.unit = u;
            v.rig = rig;
            v._blinkSeed = (u != null ? u.uid * 37 : 11) % 90;
            v._idleT = v._blinkSeed * 0.7f;
            return v;
        }

        void Update()
        {
            if (unit == null || rig == null) return;
            float dt = Time.deltaTime;
            var t = rig;
            bool alive = unit.alive;
            _idleT += dt;

            float yaw = transform.eulerAngles.y;
            float wantYaw = (unit.facing >= 0f ? 0f : 180f) + yawOffset;
            float nextYaw = Mathf.LerpAngle(yaw, wantYaw, 1f - Mathf.Exp(-12f * dt));
            float yawDelta = Mathf.DeltaAngle(yaw, nextYaw);
            _turnLean = Mathf.Lerp(_turnLean, Mathf.Clamp(yawDelta * 2.2f, -10f, 10f),
                1f - Mathf.Exp(-10f * dt));
            transform.rotation = Quaternion.Euler(0f, nextYaw, 0f);

            if (!alive)
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
                SetFace(2);
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
            _phase += dt * 8.0f * (0.25f + 0.75f * _moveK);

            float atk = unit.atkAnim > 0f ? Mathf.Clamp01(1f - unit.atkAnim / 0.34f) : 0f;
            float cast = unit.castAnim > 0f ? Mathf.Clamp01(1f - unit.castAnim / 0.5f) : 0f;
            float hurt = unit.hurtAnim > 0f ? unit.hurtAnim / 0.22f : 0f;
            float atkArc = Mathf.Sin(atk * Mathf.PI);
            float swing = Mathf.Sin(_phase);
            float breath = Mathf.Sin(Time.time * 1.5f + _blinkSeed);
            float idle = Mathf.Sin(_idleT * 0.85f + _blinkSeed * 0.3f);
            float h = t.height;

            // ---- 挤压回弹 + 攻击前冲 ----
            float squashTarget = hurt * 0.055f + atkArc * 0.028f;
            if (_moveK < 0.2f && _lastMoveK > 0.55f) squashTarget = Mathf.Max(squashTarget, 0.045f);
            _squash = Mathf.Lerp(_squash, squashTarget, 1f - Mathf.Exp(-24f * dt));
            transform.localScale = new Vector3(1f + _squash * 0.45f, 1f - _squash, 1f + _squash * 0.45f);
            float lungeWant = atk > 0f ? Mathf.Sin(Mathf.Clamp01((atk - 0.24f) / 0.52f) * Mathf.PI) * h * 0.034f : 0f;
            _lunge = Mathf.Lerp(_lunge, lungeWant, 1f - Mathf.Exp(-24f * dt));
            transform.position = new Vector3(unit.pos.x, 0f, unit.pos.z) + transform.right * _lunge;

            // ---- 髋：起伏 + 侧摆 + 待机重心 ----
            float bob = Mathf.Sin(_phase * 2f) * h * 0.014f * _moveK + breath * h * 0.0026f
                        - atkArc * h * 0.006f;
            float sway = swing * h * 0.010f * _moveK + idle * h * 0.0035f * (1f - _moveK);
            float hipRoll = swing * 3.6f * _moveK + _turnLean * 0.35f;
            t.hips.localPosition = new Vector3(0f, h * 0.40f + bob, sway);
            t.hips.localRotation = Quaternion.Euler(hipRoll, -swing * 6f * _moveK + idle * 1.6f, 0f);

            // ---- 胸：反向转体 + 前倾 + 受击后仰 ----
            float twist = atk > 0f ? Mathf.Lerp(-22f, 24f, Ease(Mathf.Clamp01(atk / 0.7f)))
                : -swing * 6f * _moveK + idle * 2.2f * (1f - _moveK);
            float lean = -7f * _moveK + _turnLean * 0.55f - atkArc * 6f
                         + hurt * 10f + cast * 4f + breath * 0.7f;
            t.chest.localRotation = Quaternion.Euler(hurt * 5f + hipRoll * 0.25f, twist, lean);

            // ---- 腿：四相步态（接触/下沉/通过/抬起）----
            float legAmp = 32f * _moveK;
            float lSwing = swing, rSwing = -swing;
            float lKnee = Mathf.Max(0f, Mathf.Sin(_phase + 0.55f)) * 36f * _moveK;
            float rKnee = Mathf.Max(0f, Mathf.Sin(_phase + 0.55f + Mathf.PI)) * 36f * _moveK;
            float stance = atkArc * 7f;
            t.thL.localRotation = Quaternion.Euler(0f, 0f, lSwing * legAmp + stance);
            t.thR.localRotation = Quaternion.Euler(0f, 0f, rSwing * legAmp - stance * 0.6f);
            t.knL.localRotation = Quaternion.Euler(0f, 0f, -lKnee - atkArc * 6f);
            t.knR.localRotation = Quaternion.Euler(0f, 0f, -rKnee - atkArc * 4f);
            t.anL.localRotation = Quaternion.Euler(0f, 0f, -(lSwing * legAmp - lKnee) * 0.45f + 2f);
            t.anR.localRotation = Quaternion.Euler(0f, 0f, -(rSwing * legAmp - rKnee) * 0.45f + 2f);

            // ---- 手臂：对侧摆 + 蓄力/出手/收势 ----
            float armSwing = swing * 26f * _moveK + idle * 1.5f * (1f - _moveK);
            float zL = -armSwing, zR = armSwing;
            float elbowL = 10f + Mathf.Abs(swing) * 7f * _moveK;
            float elbowR = elbowL;
            if (atk > 0f)
            {
                if (atk < 0.32f)
                {
                    float k = Ease(atk / 0.32f);
                    zR = Mathf.Lerp(zR, -72f, k);
                    zL = Mathf.Lerp(zL, -34f, k);
                    elbowR = Mathf.Lerp(elbowR, 84f, k);
                    elbowL = Mathf.Lerp(elbowL, 38f, k);
                }
                else if (atk < 0.66f)
                {
                    float k = Ease((atk - 0.32f) / 0.34f);
                    zR = Mathf.Lerp(-72f, 106f, k);
                    zL = Mathf.Lerp(-34f, 38f, k);
                    elbowR = Mathf.Lerp(84f, 2f, k);
                    elbowL = Mathf.Lerp(38f, 12f, k);
                }
                else
                {
                    float k = Ease((atk - 0.66f) / 0.34f);
                    zR = Mathf.Lerp(106f, armSwing, k);
                    zL = Mathf.Lerp(38f, -armSwing, k);
                    elbowR = Mathf.Lerp(2f, elbowR, k);
                    elbowL = Mathf.Lerp(12f, elbowL, k);
                }
            }
            if (cast > 0f)
            {
                float k = Mathf.Sin(Mathf.Clamp01(cast) * Mathf.PI);
                zR = Mathf.Lerp(zR, 112f, k);
                zL = Mathf.Lerp(zL, 54f, k);
                elbowR = Mathf.Lerp(elbowR, 12f, k);
                elbowL = Mathf.Lerp(elbowL, 26f, k);
            }
            if (hurt > 0f)
            {
                zR = Mathf.Lerp(zR, 48f, hurt);
                zL = Mathf.Lerp(zL, -26f, hurt);
                elbowR = Mathf.Lerp(elbowR, 60f, hurt);
            }
            t.shL.localRotation = Quaternion.Euler(-6f + hurt * 8f, 0f, zL);
            t.shR.localRotation = Quaternion.Euler(6f - hurt * 8f, 0f, zR);
            t.elL.localRotation = Quaternion.Euler(0f, 0f, elbowL);
            t.elR.localRotation = Quaternion.Euler(0f, 0f, elbowR);
            t.wrL.localRotation = Quaternion.Euler(0f, 0f, -elbowL * 0.18f);
            t.wrR.localRotation = Quaternion.Euler(0f, 0f, -elbowR * 0.18f);

            // ---- 头：看向镜头 + 点头/滞后 + 待机小晃 ----
            float lookYaw = 0f;
            var cam = CameraRig.I != null ? CameraRig.I.cam : null;
            if (cam != null)
            {
                Vector3 cd = cam.transform.position - t.head.position;
                float camYaw = Mathf.Atan2(-cd.z, cd.x) * Mathf.Rad2Deg;
                float bodyYaw = transform.eulerAngles.y + t.chest.localEulerAngles.y;
                float k = moving ? 0.5f : 1f;
                if (atk > 0f || cast > 0f) k *= 0.45f;
                if (hurt > 0f) k *= 0.35f;
                lookYaw = Mathf.Clamp(Mathf.DeltaAngle(bodyYaw, camYaw) * 0.55f, -44f, 44f) * k;
            }
            lookYaw += idle * 3.5f * (1f - _moveK);
            float nod = -atkArc * 9f + cast * 11f - hurt * 7f + breath * 1.6f + idle * 1.2f;
            t.neck.localRotation = Quaternion.Euler(hurt * -5f, lookYaw * 0.3f, nod * 0.4f);
            t.head.localRotation = Quaternion.Euler(
                hurt * -6f + Mathf.Sin(_phase * 2f) * 1.5f * _moveK + idle * 1.5f,
                lookYaw * 0.7f + Mathf.Sin(_phase) * 3f * _moveK,
                nod * 0.6f + _turnLean * 0.3f);

            // ---- 尾巴 / 耳朵：跟随与偶发抽动 ----
            float tailWag = Mathf.Sin(Time.time * (2.1f + _moveK * 1.4f) + _blinkSeed * 0.1f);
            t.tail1.localRotation = Quaternion.Euler(tailWag * 8f, 0f,
                16f + tailWag * 10f + _moveK * 8f - hurt * 10f);
            t.tail2.localRotation = Quaternion.Euler(tailWag * 10f, 0f, tailWag * 12f + 4f - hurt * 6f);
            float twitch = Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Time.time * 0.9f + _blinkSeed * 0.7f)), 16f) * 13f;
            t.earL.localRotation = Quaternion.Euler(
                -10f + Mathf.Sin(Time.time * 2.3f + 0.4f) * 5f - hurt * 12f - twitch, 0f, 0f);
            t.earR.localRotation = Quaternion.Euler(
                10f + Mathf.Sin(Time.time * 2.3f + 1.6f) * 5f - hurt * 12f, 0f, 0f);

            // ---- 脚步扬尘 ----
            int step = Mathf.FloorToInt(_phase / Mathf.PI);
            if (step != _stepMark)
            {
                _stepMark = step;
                /* 只给玩家脚下扬尘：六个英雄同时扬尘的粒子/draw call 不划算 */
                if (_moveK > 0.35f && unit.isPlayer)
                {
                    var foot = ((step & 1) == 0) ? t.anL : t.anR;
                    Fx.Dust(new Vector3(foot.position.x, 0f, foot.position.z),
                        new Color(0.80f, 0.77f, 0.60f, 0.5f));
                }
            }
            _lastMoveK = _moveK;

            // ---- 施法起手的一小簇光 ----
            if (unit.castAnim > 0f && !_castFx)
            {
                _castFx = true;
                Vector3 cp = t.weapon != null ? t.weapon.position : t.wrR.position;
                Fx.Muzzle(cp, unit.def != null ? unit.def.accent : Color.white);
            }
            if (unit.castAnim <= 0f) _castFx = false;

            // ---- 脸：眨眼 / 受击换图 ----
            _blinkT -= dt;
            if (_blinkT < 0f)
            {
                _faceHold = 0.13f;
                _blinkT = 2.4f + Mathf.Abs(_blinkSeed % 7) * 0.3f;
            }
            _faceHold = Mathf.Max(0f, _faceHold - dt);
            SetFace(hurt > 0.1f ? 2 : 0);
            if (rig.eyes != null)
            {
                float eyeY = _faceHold > 0f ? 0.12f : (hurt > 0.1f ? 0.55f : 1f);
                var es = rig.eyes.localScale;
                rig.eyes.localScale = new Vector3(es.x, Mathf.Lerp(es.y, eyeY, 1f - Mathf.Exp(-30f * dt)), es.z);
            }

            // ---- 受击闪白 ----
            _flash = Mathf.Lerp(_flash, hurt, 1f - Mathf.Exp(-20f * dt));
            ApplyFlash(_flash);
        }

        void SetFace(int mode)
        {
            if (rig.faceMat == null || rig.faceOpen == null) return;
            var tex = mode == 2 && rig.faceHurt != null ? rig.faceHurt
                : mode == 1 && rig.faceBlink != null ? rig.faceBlink : rig.faceOpen;
            if (rig.faceMat.mainTexture != tex) rig.faceMat.mainTexture = tex;
        }

        void ApplyFlash(float f)
        {
            f = Mathf.Clamp01(f * 0.8f);
            for (int i = 0; i < rig.mats.Length; i++)
                if (rig.mats[i] != null && rig.mats[i].HasProperty("_Flash"))
                    rig.mats[i].SetFloat(FlashId, f);
        }

        static float Ease(float t) => t * t * (3f - 2f * t);
    }
}
