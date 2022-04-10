#define PI 3.1415926535898

//F 
float Pow5(float v)
{
    return v*v * v*v * v;
}
float3 calc_Fresnel(float cosA, float3 F0) 
{
    return F0 + (1 - F0) * Pow5(1.0 - cosA);
}
//用于计算 kd
half3 FresnelLerp (half3 F0, half3 F90, half cosA)
{
    half t = Pow5 (1 - cosA);   // ala Schlick interpoliation
    return lerp (F0, F90, t);
}

//D
float calc_NDF_GGX(float ndoth, float roughness) 
{
    float a = roughness * roughness;
    float a2 = a * a;
    float ndoth2 = ndoth * ndoth;
    float t = ndoth2 * (a2 - 1.0) + 1.0;
    float t2 = t * t;
    return a2 / (PI * t2);
}

// G 
float calc_Geometry_SmithGGX_Direct(float ndotv,float ndotl, float roughness) 
{
    float a = roughness;
    float k = ((roughness+1) * (roughness+1)) / 8.0;

    float ggx1 = ndotv / (ndotv * (1.0- k) + k);
    float ggx2 = ndotl / (ndotl * (1.0-k) + k);
    return ggx1 * ggx2;    
}

// G 
half calc_Geometry_SmithGGX_IBL (half ndotl, half ndotv, half roughness)
{
    float a = roughness;
    float k = (a*a) / 2.0;

    float ggx1 = ndotv / (ndotv * (1.0-k) + k);
    float ggx2 = ndotl / (ndotl * (1.0-k) + k);
    return ggx1 * ggx2;  
}

float radicalInverse(uint bits) 
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10f;
}
//均匀的二维采样
float2 hammersley(uint i, uint N) 
{
    return float2(float(i) / float(N), radicalInverse(i));
}

float3 importance_sampling_ggx(float2 xi, float roughness, float3 n) 
{
    float a = roughness * roughness;

    float phi = 2.0 * PI * xi.x;
    float costheta = sqrt((1.0 - xi.y) / (1.0 + (a*a - 1.0) * xi.y));
    float sintheta = sqrt(1.0 - costheta * costheta);

    //球面坐标 -> 笛卡尔坐标
    float3 h = float3(sintheta * cos(phi), sintheta * sin(phi), costheta);

    float3 up = abs(n.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 tx = normalize(cross(up, n));
    float3 ty = cross(n, tx);
    float3x3 TBN = float3x3(tx, ty, n);

    //return tx * h.x + ty * h.y + n * h.z;
    return mul(h, TBN);
}



