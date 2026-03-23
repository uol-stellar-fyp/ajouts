Shader "Custom/GRLensingWithAccrDisk"
{
    Properties
    {
        _Steps ("Amount of steps", int) = 256
        _StepSize ("Step size", Range(0.001,1)) = 0.1

        _SSRadius ("Object relative Schwarzschild radius", Range(0,1)) = 0.35
        _GConst ("Gravitational constant", float) = 0.3

        _DiscWidth ("Width of the accretion disc", float) = 0.1
        _DiscOuterRadius("Object relative outer disc radius", Range(0,1)) = 1.0
        _DiscInnerRadius("Object relative disc inner radius", Range(0,1)) = 0.25
        _DiscTex ("Disc texture", 2D) = "white" {}
        _DiscSpeed ("Disc rotation speed", float) = 2.0

        [HDR]_DiscColor ("Disc main color", Color) = (1,0.4,0.1,1)
        _DopplerBeamingFactor ("Doppler beaming factor", float) = 66.0
        _HueRadius ("Hue shift start radius", Range(0,1)) = 0.75
        _HueShiftFactor ("Hue shifting factor", float) = -0.03
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Transparent"
        }
        Cull Front

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            static const float maxFloat = 3.402823466e+38;

            // ── Properties ────────────────────────────────────────────────────
            int _Steps;
            float _StepSize;
            float _SSRadius;
            float _GConst;

            float _DiscWidth;
            float _DiscOuterRadius;
            float _DiscInnerRadius;
            float _DiscSpeed;

            Texture2D<float4> _DiscTex;
            SamplerState sampler_DiscTex;
            float4 _DiscTex_ST;

            float4 _DiscColor;
            float _DopplerBeamingFactor;
            float _HueRadius;
            float _HueShiftFactor;

            // ── Vertex structs ────────────────────────────────────────────────
            struct Attributes
            {
                float4 posOS : POSITION;
            };

            struct v2f
            {
                float4 posCS : SV_POSITION;
                float3 posWS : TEXCOORD0;
                float3 centre : TEXCOORD1;
                float3 objectScale : TEXCOORD2;
            };

            // ── Vertex shader ─────────────────────────────────────────────────
            v2f vert(Attributes IN)
            {
                v2f OUT = (v2f)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.posOS.xyz);
                OUT.posCS = vertexInput.positionCS;
                OUT.posWS = vertexInput.positionWS;

                OUT.centre = UNITY_MATRIX_M._m03_m13_m23;
                OUT.objectScale = float3(
                    length(float3(UNITY_MATRIX_M[0].x, UNITY_MATRIX_M[1].x, UNITY_MATRIX_M[2].x)),
                    length(float3(UNITY_MATRIX_M[0].y, UNITY_MATRIX_M[1].y, UNITY_MATRIX_M[2].y)),
                    length(float3(UNITY_MATRIX_M[0].z, UNITY_MATRIX_M[1].z, UNITY_MATRIX_M[2].z)));

                return OUT;
            }

            // ── Intersection helpers ──────────────────────────────────────────

            float2 intersectSphere(float3 rayOrigin, float3 rayDir,
                                   float3 centre, float radius)
            {
                float3 offset = rayOrigin - centre;
                const float a = 1;
                float b = 2 * dot(offset, rayDir);
                float c = dot(offset, offset) - radius * radius;
                float discriminant = b * b - 4 * a * c;

                if (discriminant > 0)
                {
                    float s = sqrt(discriminant);
                    float near = max(0, (-b - s) / (2 * a));
                    float far = (-b + s) / (2 * a);
                    if (far >= 0)
                        return float2(near, far - near);
                }
                return float2(maxFloat, 0);
            }

            float2 intersectInfiniteCylinder(float3 rayOrigin, float3 rayDir,
                                             float3 cylOrigin, float3 cylDir,
                                             float cylRadius)
            {
                float3 a0 = rayDir - dot(rayDir, cylDir) * cylDir;
                float a = dot(a0, a0);

                float3 dP = rayOrigin - cylOrigin;
                float3 c0 = dP - dot(dP, cylDir) * cylDir;
                float c = dot(c0, c0) - cylRadius * cylRadius;

                float b = 2 * dot(a0, c0);
                float discriminant = b * b - 4 * a * c;

                if (discriminant > 0)
                {
                    float s = sqrt(discriminant);
                    float near = max(0, (-b - s) / (2 * a));
                    float far = (-b + s) / (2 * a);
                    if (far >= 0)
                        return float2(near, far - near);
                }
                return float2(maxFloat, 0);
            }

            float intersectInfinitePlane(float3 rayOrigin, float3 rayDir,
                                         float3 planeOrigin, float3 planeDir)
            {
                float b = dot(rayDir, planeDir);
                float c = dot(rayOrigin, planeDir) - dot(planeDir, planeOrigin);
                return -c / b;
            }

            float intersectDisc(float3 rayOrigin, float3 rayDir,
                                float3 p1, float3 p2,
                                float3 discDir, float discRadius,
                                float innerRadius)
            {
                float discDst = maxFloat;

                float2 cylInt = intersectInfiniteCylinder(
                    rayOrigin, rayDir, p1, discDir, discRadius);
                float cylDst = cylInt.x;

                if (cylDst < maxFloat)
                {
                    float finiteC1 = dot(discDir, rayOrigin + rayDir * cylDst - p1);
                    float finiteC2 = dot(discDir, rayOrigin + rayDir * cylDst - p2);

                    if (finiteC1 > 0 && finiteC2 < 0 && cylDst > 0)
                    {
                        discDst = cylDst;
                    }
                    else
                    {
                        float radiusSqr = discRadius * discRadius;
                        float innerRadiusSqr = innerRadius * innerRadius;

                        float p1Dst = max(intersectInfinitePlane(
                                              rayOrigin, rayDir, p1, discDir), 0);
                        float3 q1 = rayOrigin + rayDir * p1Dst;
                        float p1q1DstSqr = dot(q1 - p1, q1 - p1);

                        if (p1Dst > 0 && p1q1DstSqr < radiusSqr
                            && p1q1DstSqr > innerRadiusSqr)
                            if (p1Dst < discDst) discDst = p1Dst;

                        float p2Dst = max(intersectInfinitePlane(
                                              rayOrigin, rayDir, p2, discDir), 0);
                        float3 q2 = rayOrigin + rayDir * p2Dst;
                        float p2q2DstSqr = dot(q2 - p2, q2 - p2);

                        if (p2Dst > 0 && p2q2DstSqr < radiusSqr
                            && p2q2DstSqr > innerRadiusSqr)
                            if (p2Dst < discDst) discDst = p2Dst;
                    }
                }
                return discDst;
            }

            // ── Utility ───────────────────────────────────────────────────────

            float remap(float v, float minOld, float maxOld,
                        float minNew, float maxNew)
            {
                return minNew + (v - minOld) * (maxNew - minNew) / (maxOld - minOld);
            }

            float2 discUV(float3 planarDiscPos, float3 discDir,
                          float3 centre, float radius)
            {
                float3 planarNorm = normalize(planarDiscPos);
                float sampleDist01 = length(planarDiscPos) / radius;

                float3 tangentTest = float3(1, 0, 0);
                if (abs(dot(discDir, tangentTest)) >= 1)
                    tangentTest = float3(0, 1, 0);

                float3 tangent = normalize(cross(discDir, tangentTest));
                float3 biTangent = cross(tangent, discDir);

                float phi = atan2(dot(planarNorm, tangent),
                                  dot(planarNorm, biTangent)) / PI;
                phi = remap(phi, -1, 1, 0, 1);

                return float2(sampleDist01, phi);
            }

            // ── Colour helpers ────────────────────────────────────────────────

            float3 LinearToGammaSpace(float3 linRGB)
            {
                linRGB = max(linRGB, float3(0, 0, 0));
                return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
            }

            float3 GammaToLinearSpace(float3 sRGB)
            {
                return sRGB * (sRGB * (sRGB * 0.305306011f
                        + 0.682171111f)
                    + 0.012522878f);
            }

            float3 hdrIntensity(float3 emissiveColor, float intensity)
            {
                #ifndef UNITY_COLORSPACE_GAMMA
                emissiveColor.rgb = LinearToGammaSpace(emissiveColor.rgb);
                #endif
                emissiveColor.rgb *= pow(2.0, intensity);
                #ifndef UNITY_COLORSPACE_GAMMA
                emissiveColor.rgb = GammaToLinearSpace(emissiveColor.rgb);
                #endif
                return emissiveColor;
            }

            float3 RGBToHSV(float3 c)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
                              d / (q.x + e), q.x);
            }

            float3 HSVToRGB(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
            }

            float3 RotateAboutAxis(float3 In, float3 Axis, float Rotation)
            {
                float s = sin(Rotation);
                float c = cos(Rotation);
                float omc = 1.0 - c;
                Axis = normalize(Axis);
                float3x3 m = {
                    omc * Axis.x * Axis.x + c, omc * Axis.x * Axis.y - Axis.z * s, omc * Axis.z * Axis.x + Axis.y * s,
                    omc * Axis.x * Axis.y + Axis.z * s, omc * Axis.y * Axis.y + c, omc * Axis.y * Axis.z - Axis.x * s,
                    omc * Axis.z * Axis.x - Axis.y * s, omc * Axis.y * Axis.z + Axis.x * s, omc * Axis.z * Axis.z + c
                };
                return mul(m, In);
            }

            float3 discColor(float3 baseColor, float3 planarDiscPos,
                             float3 discDir, float3 cameraPos,
                             float u, float radius)
            {
                float3 newColor = baseColor;

                float intensity = remap(u, 0, 1, 0.5, -1.2);
                intensity *= abs(intensity);

                float3 rotatePos = RotateAboutAxis(planarDiscPos, discDir, 0.01);
                float dopplerDist = (length(rotatePos - cameraPos)
                    - length(planarDiscPos - cameraPos)) / radius;
                intensity += dopplerDist * _DiscSpeed * _DopplerBeamingFactor;

                newColor = hdrIntensity(baseColor, intensity);

                float3 hsvColor = RGBToHSV(newColor);
                float hueShift = saturate(remap(u, _HueRadius, 1, 0, 1));
                hsvColor.r += hueShift * _HueShiftFactor;
                newColor = HSVToRGB(hsvColor);

                return newColor;
            }

            // ── Fragment shader ───────────────────────────────────────────────
            float4 frag(v2f IN) : SV_Target
            {
                // ── Ray setup ─────────────────────────────────────────────────
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(IN.posWS - _WorldSpaceCameraPos);

                float sphereRadius = 0.5 * min(min(IN.objectScale.x,
                                                   IN.objectScale.y),
                                               IN.objectScale.z);
                float2 outerSphereIntersect = intersectSphere(
                    rayOrigin, rayDirection, IN.centre, sphereRadius);

                // ── Disc setup ────────────────────────────────────────────────
                float3 discDir = normalize(mul(unity_ObjectToWorld,
                                               float4(0, 1, 0, 0)).xyz);
                float discRadius = sphereRadius * _DiscOuterRadius;
                float innerRadius = sphereRadius * _DiscInnerRadius;
                float3 p1 = IN.centre - 0.5 * _DiscWidth * discDir;
                float3 p2 = IN.centre + 0.5 * _DiscWidth * discDir;

                // The disc intersection function returns a world-space distance.
                // We accept a hit if the disc is within one full step of the
                // current ray position, scaled to world space.
                float discHitThreshold = _StepSize * sphereRadius * 2.0;

                // ── Raymarching state ─────────────────────────────────────────
                float blackHoleMask = 0;
                float3 samplePos = float3(maxFloat, 0, 0);
                float3 currentRayPos = rayOrigin
                    + rayDirection * outerSphereIntersect.x;
                float3 currentRayDir = rayDirection;

                if (outerSphereIntersect.x < maxFloat)
                {
                    for (int i = 0; i < _Steps; i++)
                    {
                        float3 dirToCentre = IN.centre - currentRayPos;
                        float dstToCentre = length(dirToCentre);
                        dirToCentre /= dstToCentre;

                        if (dstToCentre > sphereRadius + _StepSize)
                            break;

                        float force = _GConst / (dstToCentre * dstToCentre);
                        currentRayDir = normalize(currentRayDir
                            + dirToCentre * force * _StepSize);
                        currentRayPos += currentRayDir * _StepSize;

                        // Black hole event horizon
                        float bhDst = intersectSphere(currentRayPos, currentRayDir,
                                                      IN.centre,
                                                      _SSRadius * sphereRadius).x;
                        if (bhDst <= _StepSize)
                        {
                            blackHoleMask = 1;
                            break;
                        }

                        // Disc hit — accept whenever the disc is closer than
                        // our scaled threshold (fixes the _StepSize mismatch)
                        if (samplePos.x >= maxFloat)
                        {
                            float discDst = intersectDisc(currentRayPos, currentRayDir,
                                                          p1, p2, discDir,
                                                          discRadius, innerRadius);
                            if (discDst < discHitThreshold)
                                samplePos = currentRayPos + currentRayDir * discDst;
                        }
                    }
                }

                // ── Disc UV and colour ────────────────────────────────────────
                float2 uv = float2(0, 0);
                float3 planarDiscPos = float3(0, 0, 0);
                float texCol = 0;

                if (samplePos.x < maxFloat)
                {
                    planarDiscPos = samplePos
                        - dot(samplePos - IN.centre, discDir) * discDir
                        - IN.centre;

                    uv = discUV(planarDiscPos, discDir, IN.centre, discRadius);
                    uv.y += _Time.x * _DiscSpeed;

                    texCol = _DiscTex.SampleLevel(
                        sampler_DiscTex,
                        uv * _DiscTex_ST.xy, 0).r;
                }

                float3 discCol = discColor(_DiscColor.rgb, planarDiscPos,
                                           discDir, _WorldSpaceCameraPos,
                                           uv.x, discRadius);
                float discTransmittance = texCol * _DiscColor.a;

                // ── Space warping ─────────────────────────────────────────────────
                // float2 screenUV = IN.posCS.xy / _ScreenParams.xy;
                float2 screenUV = IN.posCS.xy / _ScaledScreenParams.xy;

                float3 distortedRayDir = normalize(currentRayPos - rayOrigin);
                float4 rayCameraSpace = mul(unity_WorldToCamera,
                                            float4(distortedRayDir, 0));
                float4 rayUVProjection = mul(unity_CameraProjection,
                                             float4(rayCameraSpace));
                float2 distortedScreenUV = rayUVProjection.xy * 0.5 + 0.5;

                float edgeFadeX = smoothstep(0, 0.25,
                                             1 - abs(remap(screenUV.x, 0, 1, -1, 1)));
                float edgeFadeY = smoothstep(0, 0.25,
                                             1 - abs(remap(screenUV.y, 0, 1, -1, 1)));

                // Also fade based on how far the distorted UV has wandered off screen
                float distortedEdgeFadeX = smoothstep(0, 0.02,
                                                      1 - abs(remap(distortedScreenUV.x, 0, 1, -1, 1)));
                float distortedEdgeFadeY = smoothstep(0, 0.02,
                                                      1 - abs(remap(distortedScreenUV.y, 0, 1, -1, 1)));
                float distortedEdgeFade = distortedEdgeFadeX * distortedEdgeFadeY;

                float warpT = saturate(remap(outerSphereIntersect.y,
                                             sphereRadius, 2 * sphereRadius,
                                             0, 1))
                    * edgeFadeX * edgeFadeY
                    * distortedEdgeFade; // <-- this is the key addition

                distortedScreenUV = lerp(screenUV, distortedScreenUV, warpT);
                distortedScreenUV = clamp(distortedScreenUV, 0.001, 0.999);

                // ── Composite ─────────────────────────────────────────────────
                float3 bgColor = SampleSceneColor(distortedScreenUV)
                    * (1 - blackHoleMask);
                float3 finalColor = lerp(bgColor, discCol, discTransmittance);

                return float4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}