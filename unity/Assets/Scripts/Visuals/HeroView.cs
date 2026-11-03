using UnityEngine;

namespace TapArena
{
    /// <summary>
    /// 程序化角色动画：四相步态 + 髋/胸/头分层 + 攻击/施法/受击/阵亡。
    /// 贴图脸在眨眼/受击时换图；蒙皮四肢由 CpuLimb 在 LateUpdate 里变形。
    /// </summary>
    public class HeroView : MonoBehaviour
    {
        public Unit unit;
        public float yawOffset;

        Art.Rig rig;
        float _phase, _moveK, _deathP, _blinkT = 2f, _faceHold, _flash;
        int _blinkSeed;
        static readonly int FlashId = Shader.PropertyToID("_Flash");

        public static HeroView Attach(Unit u, Art.Rig rig)
        {
            var v = rig.root.gameObject.AddComponent<HeroView>();
            v.unit = u;
            v.rig = rig;
            v._blinkSeed = (u != null ? u.uid * 37 : 11) % 90;
            return v;
        }

        void Update()
        {
            if (unit == null || rig == null) return;
            float dt = Time.deltaTime;
            var t = rig;
            bool alive = unit.alive;

            transform.position = new Vector3(unit.pos.x,
                alive ? Mathf.Max(0f, transform.position.y) : transform.position.y, unit.pos.z);
            float wantYaw = (unit.facing >= 0f ? 0f : 180f) + yawOffset;
            transform.rotation = Quaternion.Euler(0f, Mathf.LerpAngle(transform.rotation.eulerAngles.y, wantYaw,
                1f - Mathf.Exp(-12f * dt)), 0f);

            if (!alive)
            {
                _deathP = Mathf.Min(1f, _deathP + dt * 1.5f);
                transform.rotation = Quaternion.Euler(0f, transform.rotation.eulerAngles.y, -_deathP * 74f);
                transform.position += Vector3.down * dt * 12f;
                SetFace(2);
                _flash = Mathf.Lerp(_flash, 1f, dt * 4f);
                ApplyFlash(_flash);
                return;
            }
            if (_deathP > 0f)
            {
                _deathP = Mathf.Max(0f, _deathP - dt * 3.4f);
                transform.rotation = Quaternion.Euler(0f, transform.rotation.eulerAngles.y, -_deathP * 74f);
            }

            bool moving = unit.moving;
            _moveK = Mathf.Lerp(_moveK, moving ? 1f : 0f, 1f - Mathf.Exp(-9f * dt));
            _phase += dt * 8.0f * (0.25f + 0.75f * _moveK);

            float atk = unit.atkAnim > 0f ? 1f - unit.atkAnim / 0.26f : 0f;
            float cast = unit.castAnim > 0f ? 1f - unit.castAnim / 0.42f : 0f;
            float hurt = unit.hurtAnim > 0f ? unit.hurtAnim / 0.22f : 0f;
            float atkArc = Mathf.Sin(atk * Mathf.PI);
            float swing = Mathf.Sin(_phase);
            float breath = Mathf.Sin(Time.time * 1.55f + _blinkSeed);

            // ---- 髋：上下弹 + 左右摆 ----
            float h = t.height;
            float bob = Mathf.Sin(_phase * 2f) * h * 0.011f * _moveK + breath * h * 0.0025f;
            float sway = swing * h * 0.008f * _moveK;
            t.hips.localPosition = new Vector3(0f, h * 0.40f + bob, sway);
            t.hips.localRotation = Quaternion.Euler(0f, -swing * 5f * _moveK, 0f);

            // ---- 胸：反向转体 + 前倾 ----
            float twist = atk > 0f ? Mathf.Lerp(-20f, 22f, Ease(atk)) : -swing * 5f * _moveK;
            t.chest.localRotation = Quaternion.Euler(hurt * 6f, twist,
                -atkArc * 8f + hurt * 11f + cast * 4f + breath * 0.6f);

            // ---- 腿：四相步态（接触/下沉/通过/抬起）----
            float legAmp = 34f * _moveK;
            float lSwing = swing, rSwing = -swing;
            float lKnee = Mathf.Max(0f, Mathf.Sin(_phase + 0.55f)) * 34f * _moveK;
            float rKnee = Mathf.Max(0f, Mathf.Sin(_phase + 0.55f + Mathf.PI)) * 34f * _moveK;
            float stance = atkArc * 6f;
            t.thL.localRotation = Quaternion.Euler(0f, 0f, lSwing * legAmp + stance);
            t.thR.localRotation = Quaternion.Euler(0f, 0f, rSwing * legAmp - stance * 0.6f);
            t.knL.localRotation = Quaternion.Euler(0f, 0f, -lKnee - atkArc * 6f);
            t.knR.localRotation = Quaternion.Euler(0f, 0f, -rKnee - atkArc * 4f);
            // 脚踝回正，靴子尽量贴地
            t.anL.localRotation = Quaternion.Euler(0f, 0f, -(lSwing * legAmp - lKnee) * 0.45f + 2f);
            t.anR.localRotation = Quaternion.Euler(0f, 0f, -(rSwing * legAmp - rKnee) * 0.45f + 2f);

            // ---- 手臂：对侧摆 + 攻击蓄力/甩出 ----
            float armSwing = swing * 24f * _moveK;
            float zL = -armSwing, zR = armSwing;
            float elbowL = 10f + Mathf.Abs(swing) * 6f * _moveK;
            float elbowR = 10f + Mathf.Abs(swing) * 6f * _moveK;
            if (atk > 0f)
            {
                if (atk < 0.36f)
                {
                    float k = atk / 0.36f;
                    zR = Mathf.Lerp(zR, -70f, k);
                    zL = Mathf.Lerp(zL, -30f, k);
                    elbowR = Mathf.Lerp(elbowR, 82f, k);
                    elbowL = Mathf.Lerp(elbowL, 38f, k);
                }
                else
                {
                    float k = Mathf.Clamp01((atk - 0.36f) / 0.64f);
                    float hit = Mathf.Sin(k * Mathf.PI * 0.92f);
                    zR = Mathf.Lerp(-70f, 102f, hit);
                    zL = Mathf.Lerp(-30f, 34f, hit);
                    elbowR = Mathf.Lerp(82f, 4f, k);
                    elbowL = Mathf.Lerp(38f, 14f, k);
                }
            }
            if (cast > 0f)
            {
                float k = Mathf.Sin(Mathf.Clamp01(cast) * Mathf.PI);
                zR = Mathf.Lerp(zR, 108f, k);
                zL = Mathf.Lerp(zL, 52f, k);
                elbowR = Mathf.Lerp(elbowR, 14f, k);
                elbowL = Mathf.Lerp(elbowL, 28f, k);
            }
            if (hurt > 0f)
            {
                zR = Mathf.Lerp(zR, 44f, hurt);
                zL = Mathf.Lerp(zL, -22f, hurt);
                elbowR = Mathf.Lerp(elbowR, 58f, hurt);
            }
            t.shL.localRotation = Quaternion.Euler(4f + hurt * 8f, 0f, zL);
            t.shR.localRotation = Quaternion.Euler(-4f - hurt * 8f, 0f, zR);
            t.elL.localRotation = Quaternion.Euler(0f, 0f, elbowL);
            t.elR.localRotation = Quaternion.Euler(0f, 0f, elbowR);
            t.wrL.localRotation = Quaternion.Euler(0f, 0f, -elbowL * 0.18f);
            t.wrR.localRotation = Quaternion.Euler(0f, 0f, -elbowR * 0.18f);

            // ---- 头：看向镜头 + 点头/滞后 ----
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
                lookYaw = Mathf.Clamp(Mathf.DeltaAngle(bodyYaw, camYaw) * 0.45f, -26f, 26f) * k;
            }
            float nod = -atkArc * 8f + cast * 10f - hurt * 6f + breath * 1.6f;
            t.neck.localRotation = Quaternion.Euler(hurt * -5f, lookYaw * 0.3f, nod * 0.4f);
            t.head.localRotation = Quaternion.Euler(hurt * -6f + Mathf.Sin(_phase * 2f) * 1.5f * _moveK,
                lookYaw * 0.7f + Mathf.Sin(_phase) * 3f * _moveK, nod * 0.6f);

            // ---- 尾巴 / 耳朵 ----
            float tailWag = Mathf.Sin(Time.time * 2.1f + _blinkSeed * 0.1f);
            t.tail1.localRotation = Quaternion.Euler(tailWag * 8f, 0f, 16f + tailWag * 10f - hurt * 8f);
            t.tail2.localRotation = Quaternion.Euler(tailWag * 10f, 0f, tailWag * 12f + 4f);
            t.earL.localRotation = Quaternion.Euler(-6f + Mathf.Sin(Time.time * 2.3f + 0.4f) * 5f - hurt * 12f, 0f, 0f);
            t.earR.localRotation = Quaternion.Euler(6f + Mathf.Sin(Time.time * 2.3f + 1.6f) * 5f - hurt * 12f, 0f, 0f);

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
