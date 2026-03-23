Shader "Custom/StarfieldSkybox"
{
    Properties
    {
        _StarDensity     ("Star Density",        Float) = 60.0
        _TwinkleSpeed    ("Twinkle Speed",       Float) = 1.2
        _StarBrightness  ("Star Brightness",     Float) = 1.0
        _MinStarSize     ("Min Star Size",       Float) = 0.02
        _MaxStarSizeBonus("Max Star Size Bonus", Float) = 0.04
    }

    SubShader
    {
        Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
        Cull Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _StarDensity;
                float _TwinkleSpeed;
                float _StarBrightness;
                float _MinStarSize;
                float _MaxStarSizeBonus;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                // The object-space position of a skybox mesh is the same as
                // its direction vector from the origin, which we use as UV.
                float3 direction   : TEXCOORD0;
            };

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.direction   = IN.positionOS.xyz;
                return OUT;
            }

            float Hash(float2 seed)
            {
                return frac(sin(dot(seed, float2(127.1, 311.7))) * 43758.5453);
            }

            half4 Frag(Varyings IN) : SV_Target
            {
                // Project the 3D view direction onto a 2D plane for star placement.
                // Normalising and using xz + y gives a smooth all-sky distribution
                // without seams across the sphere.
                float3 dir = normalize(IN.direction);

                // Two-plane projection: blend between xz and xy based on elevation
                // so stars don't bunch up at the poles.
                float2 uvA = dir.xz / (abs(dir.y) + 1.0);
                float2 uvB = dir.xy / (abs(dir.z) + 1.0);
                float  blend = abs(dir.y);
                float2 uv = lerp(uvA, uvB, blend) * _StarDensity;

                float2 cell  = floor(uv);
                float2 local = frac(uv);

                float3 color = float3(0.0, 0.0, 0.0);

                for (int x = -1; x <= 1; x++)
                {
                    for (int y = -1; y <= 1; y++)
                    {
                        float2 n    = float2(x, y);
                        float2 seed = cell + n;

                        float h1 = Hash(seed);
                        float h2 = Hash(seed + float2(1.0, 0.0));
                        float h3 = Hash(seed + float2(0.0, 99.0));
                        float h4 = Hash(seed + float2(0.0, 77.0));
                        float h5 = Hash(seed + float2(0.0, 33.0));

                        float2 starPos = float2(h1, h2);
                        float  dist    = length(local - n - starPos);

                        float size    = _MinStarSize + h3 * _MaxStarSizeBonus;
                        float phase   = h4 * 6.28318;
                        float twinkle = 0.5 + 0.5 * sin(_Time.y * _TwinkleSpeed + phase);
                        float bright  = smoothstep(size, size * 0.3, dist)
                                        * twinkle * _StarBrightness;

                        float3 warmCol = float3(1.00, 0.95, 0.80);
                        float3 coolCol = float3(0.80, 0.90, 1.00);
                        color += lerp(warmCol, coolCol, h5) * bright;
                    }
                }

                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
