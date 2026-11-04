// 低多边形角色/建筑：顶点色 + 顶点 AO + 三段卡通明暗 + 外扩描边 + 受击闪白。
// 场景植被改用 LowPolyFlat（去掉描边 pass，省一半几何）。
Shader "TapArena/LowPoly"
{
    Properties
    {
        _Color ("Tint", Color) = (1,1,1,1)
        _EmissionColor ("Emission", Color) = (0,0,0,0)
        _Outline ("Outline Width", Float) = 0.0
        _OutlineColor ("Outline Color", Color) = (0.14,0.11,0.12,1)
        _RimColor ("Rim Color", Color) = (0.85,0.95,1,1)
        _RimPower ("Rim Power", Float) = 4.0
        _RimStrength ("Rim Strength", Float) = 0.28
        _ShadeTint ("Ambient Tint", Color) = (0.72,0.80,1,1)
        _AOStrength ("Vertex AO", Range(0,1)) = 1.0
        _Flash ("Hit Flash", Range(0,1)) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "OUTLINE"
            Cull Front
            ZWrite On
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"

            float _Outline;
            fixed4 _OutlineColor;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct v2f { float4 pos : SV_POSITION; };

            v2f vert (appdata v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                v2f o;
                float3 wp = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 wn = UnityObjectToWorldNormal(v.normal);
                wp += wn * _Outline;
                o.pos = mul(UNITY_MATRIX_VP, float4(wp, 1.0));
                return o;
            }

            fixed4 frag (v2f i) : SV_Target { return _OutlineColor; }
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
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Color;
            float4 _EmissionColor;
            fixed4 _RimColor;
            fixed4 _ShadeTint;
            float _RimPower;
            float _RimStrength;
            float _AOStrength;
            float _Flash;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 wn : TEXCOORD0;
                float3 wp : TEXCOORD1;
                float4 color : COLOR;
                SHADOW_COORDS(2)
                UNITY_FOG_COORDS(3)
            };

            v2f vert (appdata v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.wn = UnityObjectToWorldNormal(v.normal);
                o.wp = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.color = v.color;
                TRANSFER_SHADOW(o)
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                /* 顶点色是 Blender 导出的 sRGB 值，转到线性再做光照。 */
                float3 albedo = pow(saturate(i.color.rgb), 2.2) * _Color.rgb;
                albedo *= lerp(1.0, saturate(i.color.a), _AOStrength);
                albedo = lerp(albedo, float3(1.0, 1.0, 1.0), saturate(_Flash));
                float3 n = normalize(i.wn);

                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                if (_WorldSpaceLightPos0.w > 0.5)
                    lightDir = normalize(_WorldSpaceLightPos0.xyz - i.wp);

                float ndl = dot(n, lightDir) * 0.5 + 0.5;
                float lit = smoothstep(0.40, 0.46, ndl) * 0.55 +
                            smoothstep(0.70, 0.76, ndl) * 0.45;

                UNITY_LIGHT_ATTENUATION(atten, i, i.wp)

                float3 ambient = ShadeSH9(float4(n, 1.0)) * _ShadeTint.rgb;
                float3 col = albedo * (_LightColor0.rgb * lit * atten + ambient);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.wp);
                float rim = pow(saturate(1.0 - dot(n, viewDir)), _RimPower) * _RimStrength;
                col += _RimColor.rgb * rim * (0.55 + 0.45 * albedo);

                col += _EmissionColor.rgb;

                fixed4 outCol = fixed4(col, 1.0);
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
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct v2f { V2F_SHADOW_CASTER; };
            v2f vert (appdata v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }
            fixed4 frag (v2f i) : SV_Target { SHADOW_CASTER_FRAGMENT(i) }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
