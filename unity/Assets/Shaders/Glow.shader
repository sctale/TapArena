// 廉价泛光 + 暗角 + 暖调：内置管线下用 OnRenderImage 一次全屏 pass 实现。
Shader "TapArena/Glow"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Threshold ("Threshold", Float) = 0.86
        _Intensity ("Intensity", Float) = 0.85
        _Vignette ("Vignette", Float) = 0.4
        _Warm ("Warm", Float) = 0.22
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _Threshold, _Intensity, _Vignette, _Warm;

            fixed3 Bright(float2 uv)
            {
                fixed3 c = tex2D(_MainTex, uv).rgb;
                return max(0.0, c - _Threshold);
            }

            fixed4 frag(v2f_img i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                float2 o = _MainTex_TexelSize.xy * 2.5;

                /* 环形 8 采样做一次廉价模糊，只在超亮处累加 */
                fixed3 bloom = Bright(i.uv + float2( o.x, 0));
                bloom += Bright(i.uv + float2(-o.x, 0));
                bloom += Bright(i.uv + float2(0,  o.y));
                bloom += Bright(i.uv + float2(0, -o.y));
                bloom += Bright(i.uv + float2( o.x,  o.y));
                bloom += Bright(i.uv + float2(-o.x,  o.y));
                bloom += Bright(i.uv + float2( o.x, -o.y));
                bloom += Bright(i.uv + float2(-o.x, -o.y));
                bloom *= 0.125;

                col.rgb += bloom * _Intensity;

                /* 暗角 */
                float2 d = i.uv - 0.5;
                float vig = saturate(1.0 - dot(d, d) * 2.4);
                col.rgb *= lerp(1.0 - _Vignette, 1.0, vig);

                /* 轻微暖调 + 提饱和 + 一点点 S 曲线，避免灰蒙蒙 */
                fixed3 warm = col.rgb * fixed3(1.05, 1.0, 0.95);
                col.rgb = lerp(col.rgb, warm, _Warm);
                float lum = dot(col.rgb, fixed3(0.299, 0.587, 0.114));
                col.rgb = lerp(lum.xxx, col.rgb, 1.14);
                col.rgb = saturate((col.rgb - 0.5) * 1.06 + 0.5);

                return col;
            }
            ENDCG
        }
    }
    Fallback Off
}
