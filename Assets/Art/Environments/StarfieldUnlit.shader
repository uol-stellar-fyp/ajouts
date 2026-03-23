Shader "Custom/StarfieldUnlit"
{
    Properties
    {
        _StarDensity     ("Star Density",      Float) = 60.0
        _TwinkleSpeed    ("Twinkle Speed",     Float) = 1.2
        _StarBrightness  ("Star Brightness",   Float) = 1.0
        _MinStarSize     ("Min Star Size",     Float) = 0.02
        _MaxStarSizeBonus("Max Star Size Bonus", Float) = 0.04
    }

    SubShader
    {
        Tags
        {
            "RenderType"      = "Opaque"
            "RenderPipeline"  = "UniversalPipeline"
            "Queue"           = "Background"
        }

        Pass
        {
            Name "StarfieldUnlit"
            Tags { "LightMode" = "UniversalForward" }

            ZWrite Off
            ZTest Always
            Cull Off

            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // ── Properties ─────────────────────────────────────────────────────
            CBUFFER_START(UnityPerMaterial)
                float _StarDensity;
                float _TwinkleSpeed;
                float _StarBrightness;
                float _MinStarSize;
                float _MaxStarSizeBonus;
            CBUFFER_END

            // ── Vertex ─────────────────────────────────────────────────────────
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
            };

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv          = IN.uv;
                return OUT;
            }

            // ── Hash ───────────────────────────────────────────────────────────
            // Returns a pseudo-random float in [0, 1] from a 2D seed.
            float Hash(float2 seed)
            {
                return frac(sin(dot(seed, float2(127.1, 311.7))) * 43758.5453);
            }

            // ── Fragment ───────────────────────────────────────────────────────
            half4 Frag(Varyings IN) : SV_Target
            {
                float2 uv    = IN.uv * _StarDensity;
                float2 cell  = floor(uv);
                float2 local = frac(uv);

                float3 color = float3(0.0, 0.0, 0.0);

                // Sample this cell and its 8 neighbours so stars near cell
                // boundaries are never clipped.
                for (int x = -1; x <= 1; x++)
                {
                    for (int y = -1; y <= 1; y++)
                    {
                        float2 n = float2(x, y);

                        // Unique hash values for this neighbouring cell
                        float2 seed = cell + n;
                        float  h1   = Hash(seed);
                        float  h2   = Hash(seed + float2(1.0, 0.0));
                        float  h3   = Hash(seed + float2(0.0, 99.0));
                        float  h4   = Hash(seed + float2(0.0, 77.0));
                        float  h5   = Hash(seed + float2(0.0, 33.0));

                        // Star sits at a random position inside its cell
                        float2 starPos = float2(h1, h2);
                        float  dist    = length(local - n - starPos);

                        // Size varies per star
                        float size = _MinStarSize + h3 * _MaxStarSizeBonus;

                        // Twinkle: each star has a unique phase
                        float phase   = h4 * 6.28318;
                        float twinkle = 0.5 + 0.5 * sin(_Time.y * _TwinkleSpeed + phase);

                        // Crisp circular disc with a soft edge
                        float bright = smoothstep(size, size * 0.3, dist)
                                       * twinkle
                                       * _StarBrightness;

                        // Warm (yellowish-white) to cool (blue-white) colour range
                        float3 warmCol = float3(1.00, 0.95, 0.80);
                        float3 coolCol = float3(0.80, 0.90, 1.00);
                        float3 starCol = lerp(warmCol, coolCol, h5);

                        color += starCol * bright;
                    }
                }

                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
