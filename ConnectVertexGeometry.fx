#include "StructLineConnection.fxh"

float4x4 tW: WORLD;
float4x4 tVP: WORLDVIEWPROJECTION;

StructuredBuffer<LineConnection> inputBuffer;
StructuredBuffer<float> alphaBuffer;

float lineWidth = 1.0f;
float lineLength = 1.0f;

float4 lineColor <bool color=true;String uiname="Color";> = { 1.0f,1.0f,1.0f,1.0f };
float gamma = 1.0f;

float3 cameraPosition = {0, 0, -1.0f};

Texture2D inputTexture <string uiname="Texture";>;

SamplerState linearSampler <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VS_IN
{
	uint iv : SV_VertexID;
};

struct GS_IN
{
	float3 srcPos : POSITION;
	float3 dstPos : TEXCOORD0;
	float4 srcColor : TEXCOORD1;
	float4 dstColor : TEXCOORD2;
};

struct PS_IN_LINE
{
	float4 pos : SV_POSITION;
	float4 col : COLOR;
};

struct PS_IN
{
	float4 pos : SV_POSITION;
	float4 col : COLOR;
	float2 uv : TEXCOORD0;
};

float pows(float a, float b) {return pow(abs(a),b)*sign(a);}

GS_IN VS(VS_IN input)
{
	uint count, dummy;
	inputBuffer.GetDimensions(count,dummy);
	
	LineConnection data = inputBuffer[input.iv];
	
	float srcAlpha = lineColor.a * data.alpha * alphaBuffer[data.srcIndex];
	float dstAlpha = lineColor.a * data.alpha * alphaBuffer[data.dstIndex];
	
	GS_IN output;
	output.srcPos = data.srcVertex; // mul(float4(data.srcVertex, 1), tWVP);
	output.dstPos = data.dstVertex; // mul(float4(data.dstVertex, 1), tWVP);
	output.srcColor = float4(lineColor.rgb, pows(srcAlpha, gamma));
	output.dstColor = float4(lineColor.rgb, pows(dstAlpha, gamma));
	return output;
}

[maxvertexcount(2)]
void GS_line(point GS_IN points[1], inout LineStream<PS_IN_LINE> output)
{
	GS_IN input = points[0];
	
	float4x4 tWVP = mul(tW, tVP);
	
	PS_IN_LINE v0, v1;
	v0.pos = mul(float4(input.srcPos, 1), tWVP);
	v0.col = input.srcColor;
	v1.pos = mul(float4(input.dstPos, 1), tWVP);
	v1.col = input.dstColor;
	
	output.Append(v0);
	output.Append(v1);
	output.RestartStrip();
}

[maxvertexcount(8)]
void GS_quad(point GS_IN points[1], inout TriangleStream<PS_IN> output)
{
	GS_IN input = points[0];
	float3 src = input.srcPos;
	float3 dst = input.dstPos;
	float3 dir = dst - src;
	
	float3 dirNormal = normalize(dir);
	float3 lineNormal = normalize(cross(cameraPosition, dir));
	
	float lw = lineWidth / 200;
	float3 directionOffset = dirNormal * lw;
	float3 normalScaled = lineNormal * lw;
	
	float3 center = (dst + src) / 2;
	float3 lengthFromCenter = dir / 2 * lineLength;
	float3 p0 = center - lengthFromCenter;
	float3 p1 = center + lengthFromCenter;

	float offsetSize = length(directionOffset);
	float lineFullSize = length(dir) + offsetSize * 2;
	float offsetSizeRate = offsetSize / lineFullSize;
	
	float4x4 tWVP = mul(tW, tVP);
	
	{
		PS_IN v;
		v.pos = mul(float4(p0 - directionOffset + normalScaled, 1), tWVP);
		v.col = input.srcColor;
		v.uv  = float2(0, 0);
		output.Append(v);
	}
	{
		PS_IN v;
		v.pos = mul(float4(p0 - directionOffset - normalScaled, 1), tWVP);
		v.col = input.srcColor;
		v.uv  = float2(0, 1);
		output.Append(v);
	}
	{
		PS_IN v;
		v.pos = mul(float4(p0 + normalScaled, 1), tWVP);
		v.col = input.srcColor;
		v.uv  = float2(0.5, 0);
		output.Append(v);
	}
	{
		PS_IN v;
		v.pos = mul(float4(p0 - normalScaled, 1), tWVP);
		v.col = input.srcColor;
		v.uv  = float2(0.5, 1);
		output.Append(v);
	}
	{
		PS_IN v;
		v.pos = mul(float4(p1 + normalScaled, 1), tWVP);
		v.col = input.dstColor;
		v.uv  = float2(0.5, 0);
		output.Append(v);
	}
	{
		PS_IN v;
		v.pos = mul(float4(p1 - normalScaled, 1), tWVP);
		v.col = input.dstColor;
		v.uv  = float2(0.5, 1);
		output.Append(v);
	}
	{
		PS_IN v;
		v.pos = mul(float4(p1 + directionOffset + normalScaled, 1), tWVP);
		v.col = input.dstColor;
		v.uv  = float2(1, 0);
		output.Append(v);
	}
	{
		PS_IN v;
		v.pos = mul(float4(p1 + directionOffset - normalScaled, 1), tWVP);
		v.col = input.dstColor;
		v.uv  = float2(1, 1);
		output.Append(v);
	}
	
	output.RestartStrip();
}

float4 PS_line(PS_IN_LINE input): SV_Target
{
	return input.col;
}

float4 PS_quad(PS_IN input): SV_Target
{
    float4 col = inputTexture.Sample(linearSampler, input.uv.xy) * input.col;
	return col;
}

float4 PS_round(PS_IN input): SV_Target
{
	if (length(input.uv - 0.5) > 0.5) { discard; }
    float4 col = inputTexture.Sample(linearSampler, input.uv.xy) * input.col;
	return col;
}

GeometryShader StreamOutGSLine = ConstructGSWithSO(CompileShader(gs_5_0, GS_line()), "SV_POSITION;COLOR;");
GeometryShader StreamOutGSQuad = ConstructGSWithSO(CompileShader(gs_5_0, GS_quad()), "SV_POSITION;COLOR;TEXCOORD0.xy;");

technique10 ConnectLine
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		SetGeometryShader(StreamOutGSLine);
		SetPixelShader( CompileShader( ps_5_0, PS_line() ) );
	}
}

technique10 ConnectQuad
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		SetGeometryShader(StreamOutGSQuad);
		SetPixelShader( CompileShader( ps_5_0, PS_quad() ) );
	}
}

technique10 ConnectRound
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		SetGeometryShader(StreamOutGSQuad);
		SetPixelShader( CompileShader( ps_5_0, PS_round() ) );
	}
}