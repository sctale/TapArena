using UnityEngine;

namespace TapArena
{
    /// <summary>输入汇总：屏幕摇杆（Hud 写入）+ 键盘（桌面调试）。技能是"按下即消费"。</summary>
    public class InputHub : MonoBehaviour
    {
        public static Vector3 Move;
        public static bool[] SkillFlag = new bool[3];
        static Vector2 _joyOrigin;
        static bool _joyActive;
        static int _joyFinger = -1;
        public static bool JoyVisible;
        public static Vector2 JoyCenter, JoyKnob;
        public static float JoyRadius = 130f;

        public static void SetSkill(int i) { if (i >= 0 && i < 3) SkillFlag[i] = true; }
        public static bool SkillPressed(int i)
        {
            if (i < 0 || i >= 3 || !SkillFlag[i]) return false;
            SkillFlag[i] = false;
            return true;
        }

        void Update()
        {
            Vector3 kb = Vector3.zero;
            if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow)) kb.x -= 1f;
            if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow)) kb.x += 1f;
            if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow)) kb.z += 1f;
            if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow)) kb.z -= 1f;
            if (Input.GetKeyDown(KeyCode.Q)) SetSkill(0);
            if (Input.GetKeyDown(KeyCode.E)) SetSkill(1);
            if (Input.GetKeyDown(KeyCode.R)) SetSkill(2);

            if (kb.sqrMagnitude > 0.01f) { Move = kb; return; }

            /* 触屏摇杆：左下三分之一起手，拖多远算多远 */
            if (Input.touchCount > 0)
            {
                bool handled = false;
                for (int i = 0; i < Input.touchCount; i++)
                {
                    var t = Input.GetTouch(i);
                    bool leftZone = t.position.x < Screen.width * 0.42f && t.position.y < Screen.height * 0.62f;
                    if (t.phase == TouchPhase.Began && !_joyActive && leftZone)
                    {
                        _joyActive = true; _joyFinger = t.fingerId;
                        _joyOrigin = t.position; JoyCenter = t.position; JoyKnob = t.position;
                    }
                    if (_joyActive && t.fingerId == _joyFinger)
                    {
                        handled = true;
                        Vector2 d = t.position - _joyOrigin;
                        float m = d.magnitude;
                        if (m > JoyRadius) d = d / m * JoyRadius;
                        JoyKnob = _joyOrigin + d;
                        Move = new Vector3(d.x / JoyRadius, 0f, d.y / JoyRadius);
                        if (t.phase == TouchPhase.Ended || t.phase == TouchPhase.Canceled)
                        {
                            _joyActive = false; _joyFinger = -1; Move = Vector3.zero;
                        }
                    }
                }
                JoyVisible = _joyActive;
                if (handled) return;
            }
            else
            {
                /* 编辑器里用鼠标拖也能走 */
                if (Input.GetMouseButtonDown(0))
                {
                    Vector2 p = Input.mousePosition;
                    if (p.x < Screen.width * 0.42f && p.y < Screen.height * 0.62f)
                    {
                        _joyActive = true; _joyOrigin = p; JoyCenter = p; JoyKnob = p;
                    }
                }
                if (Input.GetMouseButton(0) && _joyActive)
                {
                    Vector2 d = (Vector2)Input.mousePosition - _joyOrigin;
                    float m = d.magnitude;
                    if (m > JoyRadius) d = d / m * JoyRadius;
                    JoyKnob = _joyOrigin + d;
                    Move = new Vector3(d.x / JoyRadius, 0f, d.y / JoyRadius);
                }
                if (Input.GetMouseButtonUp(0) && _joyActive) { _joyActive = false; Move = Vector3.zero; }
                JoyVisible = _joyActive;
            }
            if (!_joyActive) Move = Vector3.zero;
        }
    }
}
