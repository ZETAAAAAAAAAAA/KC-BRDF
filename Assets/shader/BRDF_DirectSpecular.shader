Shader "Custom/BRDF_DirectSpecular"  
{
	Properties {
		_Albedo ("Albedo", Color) = (1,1,1,1)
		_Roughness ("Roughness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 1.0
	}

	CGINCLUDE 
    #include "UnityCG.cginc"
	#include "myBRDF.cginc"
	#define SAMPLER 128
	
	//https://blog.selfshadow.com/publications/s2017-shading-course/imageworks/s2017_pbs_imageworks_slides_v2.pdf
	float3 AverageFresnel(float3 r, float3 g)
	{
		return 0.087237 + 0.0230685*g - 0.0864902*g*g + 0.0774594*g*g*g
			+ 0.782654*r - 0.136432*r*r + 0.278708*r*r*r
			+ 0.19744*g*r + 0.0360605*g*g*r - 0.2586*g*r*r;
	}
	float whiteFrance(float3 n, float3 v,float roughness, float albedo)
	{
		float integral;

		for (int i = 0; i < SAMPLER; i++)
		{
			float2 xi = hammersley(i,SAMPLER);
			float3 h = importance_sampling_ggx(xi, roughness, n);
			float3 l = 2.0 * dot(v,h) * h - v;

			float ndoth = max(0.0, dot(n, h));
			float vdoth = max(0.0, dot(v, h));
			float ndotl = max(0.0, dot(n, l));
            float ndotv = max(0.0, dot(n, v));

			float F = 1;
			float G = calc_Geometry_SmithGGX_IBL(ndotv, ndotl, roughness);
			float D = calc_NDF_GGX(ndoth, roughness);
			float pdf = D * ndoth / (4.0 * vdoth);

			float3 numerator = D * G * F; 
		    float denominator = max((4.0 * ndotl * ndotv), 0.001);
		
			float BRDF = numerator / denominator;

			integral += BRDF * ndotl / pdf;
		}
		integral /= SAMPLER;
		return integral;
	}

	struct VertexDataCalculate
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
		float3 worldNormal : TEXCOORD1;
		float3 worldPos : TEXCOORD2;
    };

	VertexDataCalculate VertexCalculate (float4 vertex : POSITION, float2 uv : TEXCOORD0, float3 normal : NORMAL)
	{
		VertexDataCalculate o;
		o.vertex = UnityObjectToClipPos(vertex);
		o.uv = uv;
		o.worldNormal = UnityObjectToWorldNormal(normal);
		o.worldPos = mul(unity_ObjectToWorld, vertex).xyz;
		return o;
	}

	float _Roughness, _Metallic;
	float4 _Albedo;
    float4 FragmentCalculate (VertexDataCalculate i) : SV_Target
	{   
		//伽马矫正 
		_Albedo.rgb = float3(0.7216, 0.451, 0.2);
	
		_Albedo = pow(_Albedo, 2.2);

		float3 N = normalize(i.worldNormal);
		float3 V = normalize(UnityWorldSpaceViewDir(i.worldPos));
		float3 L = normalize(UnityWorldSpaceLightDir(i.worldPos));
		float3 H = normalize(V + L);		
		
		float NdotV = max(dot(N, V), 0.0);
		float NdotL = max(dot(N, L), 0.0);
		float NdotH = max(dot(N, H), 0.0);
		float VdotH = max(dot(V, H), 0.0);

		float3 F0 = lerp (unity_ColorSpaceDielectricSpec.rgb, _Albedo, _Metallic);
	
		float3 radiance = float3(1,1,1);

		float D = calc_NDF_GGX(NdotH, _Roughness);   
		float G = calc_Geometry_SmithGGX_Direct(NdotV, NdotL, _Roughness) ; 
		float3 F = calc_Fresnel(VdotH, F0);
			
		float3 numerator = D * G * F; 
		float denominator = max((4.0 * NdotL * NdotV), 0.001);
		
		float3 BRDF = numerator / denominator;
		
		//float3 color = whiteFrance(N, V, _Roughness, _Albedo).xxx;
		float3 color = BRDF * radiance * NdotL;
        
		color = color / (color + 1.0);
        color = pow(color, 1.0/2.2); 
		return float4 (color, 1);
    }
    ENDCG

    SubShader
    {
		
        pass
        {
			Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex VertexCalculate
            #pragma fragment FragmentCalculate
            ENDCG
        }

    }

	FallBack "Diffuse"
}