using UnityEngine;

namespace TapArena
{
    /// <summary>相机：跟随玩家 + 阻尼 + 战斗推镜 + 震屏。</summary>
    public class CameraRig : MonoBehaviour
    {
        public static CameraRig I;
        public Camera cam;
        public Transform target;
        Vector3 _focus;
        static float _shake;
        static float _punch;

        void Awake()
        {
            I = this;
            cam = GetComponent<Camera>();
            if (cam == null) cam = gameObject.AddComponent<Camera>();
        }

        public static void Shake(float v) { _shake = Mathf.Max(_shake, v); }
        public static void Punch(float v) { _punch = Mathf.Max(_punch, v); }

        public void SetTarget(Transform t, Vector3 pos)
        {
            target = t;
            _focus = pos;
            Snap();
        }

        public void Snap()
        {
            Vector3 p = target != null ? target.position : _focus;
            transform.position = p + Offset(1f);
            transform.LookAt(new Vector3(p.x, p.y + 34f, p.z + 66f));
        }

        Vector3 Offset(float punch)
        {
            float h = 290f / punch;
            float d = 430f / punch;
            return new Vector3(0f, h, -d);
        }

        void LateUpdate()
        {
            Vector3 p = target != null ? target.position : _focus;
            _focus = Vector3.Lerp(_focus, p, 1f - Mathf.Exp(-7f * Time.unscaledDeltaTime));
            _punch = Mathf.Lerp(_punch, 0f, 1f - Mathf.Exp(-6f * Time.unscaledDeltaTime));
            _shake = Mathf.Lerp(_shake, 0f, 1f - Mathf.Exp(-8f * Time.unscaledDeltaTime));

            Vector3 want = _focus + Offset(1f + _punch * 0.05f);
            transform.position = Vector3.Lerp(transform.position, want, 1f - Mathf.Exp(-9f * Time.unscaledDeltaTime));

            if (_shake > 0.05f)
            {
                Vector3 off = new Vector3(Random.Range(-_shake, _shake), Random.Range(-_shake, _shake) * 0.6f, 0f) * 2.2f;
                transform.position += off;
            }
            transform.LookAt(new Vector3(_focus.x, _focus.y + 34f, _focus.z + 66f));
        }
    }
}
