// 卡通渲染：三段明暗 + 冷色环境光 + 边缘光 + 外扩描边 + 阴影接收。
// 全部模型都是运行时用图元拼的，靠这一支 shader 统一成"手绘动画"的质感。
Shader "TapArena/Toon"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}
        _EmissionColor ("Emission", Color) = (0,0,0,0)
        _Outline ("Outline Width", Float) = 0.0
        _OutlineColor ("Outline Color", Color) = (0.14,0.11,0.12,1)
        _RimColor ("Rim Color", Color) = (0.85,0.95,1,1)
        _RimPower ("Rim Power", Float) = 4.0
        _RimStrength ("Rim Strength", Float) = 0.28
        _ShadeTint ("Ambient Tint", Color) = (0.72,0.80,1,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        /* 描边：把背面沿法线外扩一圈，只画背面 */
        Pass
        {
            Name "OUTLINE"
            Cull Front
            ZWrite On
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float _Outline;
            fixed4 _OutlineColor;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                float3 wp = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 wn = UnityObjectToWorldNormal(v.normal);
                wp += wn * _Outline;
                o.pos = mul(UNITY_MATRIX_VP, float4(wp, 1.0));
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return _OutlineColor;
            }
            ENDCG
        }

        Pass
        {
            Name "FORWARD"
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            float4 _EmissionColor;
            fixed4 _RimColor;
            fixed4 _ShadeTint;
            float _RimPower;
            float _RimStrength;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 wn : TEXCOORD1;
                float3 wp : TEXCOORD2;
                SHADOW_COORDS(3)
                UNITY_FOG_COORDS(4)
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.wn = UnityObjectToWorldNormal(v.normal);
                o.wp = mul(unity_ObjectToWorld, v.vertex).xyz;
                TRANSFER_SHADOW(o)
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
                float3 n = normalize(i.wn);

                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                if (_WorldSpaceLightPos0.w > 0.5)
                    lightDir = normalize(_WorldSpaceLightPos0.xyz - i.wp);

                float ndl = dot(n, lightDir) * 0.5 + 0.5;

                /* 三段色阶：暗部 / 中间调 / 亮部 */
                float lit = smoothstep(0.40, 0.46, ndl) * 0.55 + smoothstep(0.70, 0.76, ndl) * 0.45;

                UNITY_LIGHT_ATTENUATION(atten, i, i.wp)

                float3 ambient = ShadeSH9(float4(n, 1.0)) * _ShadeTint.rgb;
                float3 col = albedo * (_LightColor0.rgb * lit * atten + ambient);

                /* 边缘光：让轮廓从背景里跳出来 */
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.wp);
                float rim = pow(saturate(1.0 - dot(n, viewDir)), _RimPower) * _RimStrength;
                col += _RimColor.rgb * rim * (0.55 + 0.45 * albedo);

                col += _EmissionColor.rgb;

                fixed4 outCol = fixed4(col, _Color.a);
                UNITY_APPLY_FOG(i.fogCoord, outCol);
                return outCol;
            }
            ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On ZTest LEqual Cull Back
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };
            struct v2f
            {
                V2F_SHADOW_CASTER;
            };

            v2f vert (appdata v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
