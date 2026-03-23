Shader "Custom/GRLensingOld"
{
    Properties
    {
        _Steps ("Amount of steps", int) = 256
        _StepSize ("Step size", Range(0.001, 1)) = 0.1

        _SSRadius ("Object relative Schwarzschild radius", Range(0,1)) = 0.35//0.1

        _GConst ("Gravitational constant", float) = 0.3
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" "Queue" = "Transparent"
        }
        Cull Front

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #pragma require 2darray
            
            static const float maxFloat = 3.402823466e+38;
            int _Steps;
            float _StepSize;
            float _SSRadius;
            float _GConst;

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

            v2f vert(Attributes IN)
            {
                v2f OUT = (v2f)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.posOS.xyz);

                OUT.posCS = vertexInput.positionCS;
                OUT.posWS = vertexInput.positionWS;

                // Object information, based upon Unity's shadergraph library functions
                OUT.centre = UNITY_MATRIX_M._m03_m13_m23;
                OUT.objectScale = float3(length(float3(UNITY_MATRIX_M[0].x, UNITY_MATRIX_M[1].x, UNITY_MATRIX_M[2].x)),
                                         length(float3(UNITY_MATRIX_M[0].y, UNITY_MATRIX_M[1].y, UNITY_MATRIX_M[2].y)),
                                         length(float3(UNITY_MATRIX_M[0].z, UNITY_MATRIX_M[1].z, UNITY_MATRIX_M[2].z)));

                return OUT;
            }

            // Returns vector (x, y) where x = 'Distance to Sphere', y = 'Distance ray crosses through sphere'
            float2 intersectSphere(float3 rayOrigin, float3 rayDirection, float3 centre, float radius)
            {
                // Work out distance of ray from sphere
                float3 offset = rayOrigin - centre;

                // Work out the number of intersections
                const float a = 1;
                float b = 2 * dot(offset, rayDirection);
                float c = dot(offset, offset) - (radius * radius);
                float discriminant = (b * b) - (4 * a * c);

                // (d<0) => Zero intersections, (d==0) => 1 intersection, (d>0)=> 2 intersections
                if (discriminant > 0)
                {
                    float s = sqrt(discriminant);
                    float nearDist2Sphere = max(0, (-b - s) / (2 * a));
                    float farDist2Sphere = (-b + s) / (2 * a);

                    if (farDist2Sphere >= 0)
                    {
                        return float2(nearDist2Sphere, farDist2Sphere - nearDist2Sphere);
                    }
                }

                // Default return value
                return float2(maxFloat, 0);
            }

            float remap(float v, float minOld, float maxOld, float minNew, float maxNew)
            {
                return minNew + (v - minOld) * (maxNew - minNew) / (maxOld - minOld);
            }

            float4 frag(v2f IN) : SV_Target
            {
                // Get ray's initial position and direction
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(IN.posWS - _WorldSpaceCameraPos);


                // Optimization step: raytrace an outer sphere to confine further raytracing operations
                float sphereRadius = 0.5 * min(min(IN.objectScale.x, IN.objectScale.y), IN.objectScale.z);
                float2 outerSphereIntersection = intersectSphere(rayOrigin, rayDirection, IN.centre, sphereRadius);

                // Raymarching information
                float transmittance = 1;
                float blackHoleMask = 0;
                float3 currentRayPosition = rayOrigin + rayDirection * outerSphereIntersection.x;
                float3 currentRayDirection = rayDirection;

                // Ray intersects with the outer sphere
                if (outerSphereIntersection.x < maxFloat)
                {
                    for (int i = 0; i < _Steps; i++)
                    {
                        // The effects of gravity
                        float3 dirToCentre = IN.centre - currentRayPosition;
                        float dstToCentre = length(dirToCentre);
                        dirToCentre /= dstToCentre;

                        if (dstToCentre > sphereRadius + _StepSize)
                        {
                            break;
                        }

                        float force = _GConst / (dstToCentre * dstToCentre);
                        currentRayDirection = normalize(currentRayDirection + dirToCentre * force * _StepSize);

                        // Move ray forward
                        currentRayPosition += currentRayDirection * _StepSize;

                        float blackHoleDistance = intersectSphere(currentRayPosition, currentRayDirection, IN.centre,
                                                                  _SSRadius * sphereRadius).x;
                        if (blackHoleDistance <= _StepSize)
                        {
                            blackHoleMask = 1;
                            break;
                        }
                    }
                }

                float2 screenUV = IN.posCS.xy / _ScreenParams.xy;

                // Ray direction projection
                float3 distortedRayDir = normalize(currentRayPosition - rayOrigin);
                float4 rayCameraSpace = mul(unity_WorldToCamera, float4(distortedRayDir, 0));
                float4 rayUVProjection = mul(unity_CameraProjection, float4(rayCameraSpace));
                float2 distortedScreenUV = rayUVProjection.xy + 1 * 0.5;

                // Screen and object edge transitions
                float edgeFadex = smoothstep(0, 0.25, 1 - abs(remap(screenUV.x, 0, 1, -1, 1)));
                float edgeFadey = smoothstep(0, 0.25, 1 - abs(remap(screenUV.y, 0, 1, -1, 1)));
                float t = saturate(remap(outerSphereIntersection.y, sphereRadius, 2 * sphereRadius, 0, 1)) * edgeFadex *
                    edgeFadey;
                distortedScreenUV = lerp(screenUV, distortedScreenUV, t);

                float3 bgColor = SampleSceneColor(distortedScreenUV) * (1 - blackHoleMask);

                return float4(bgColor, 1);
            }
            ENDHLSL
        }
    }
}