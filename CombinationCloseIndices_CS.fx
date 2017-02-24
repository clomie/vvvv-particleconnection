#include "StructLineConnection.fxh"

uint threadCount;

StructuredBuffer<float3> vertexBuffer;
float distCenter, distRange;

AppendStructuredBuffer<LineConnection> Output : BACKBUFFER;

float map(float v, float a1, float a2, float b1, float b2) {
	return b1 + (b2 - b1) * ((v - a1) / (a2 - a1));
}

float calcAlpha(float dist) {
	if (dist < distCenter) {
		return map(dist, distCenter - distRange / 2, distCenter, 0, 1);
	} else {
		return map(dist, distCenter, distCenter + distRange / 2, 1, 0);
	}
}

[numthreads(32,32,1)]
void CS(uint3 dtid : SV_DispatchThreadID)
{
	if (dtid.x >= threadCount || dtid.y >= threadCount || dtid.x >= dtid.y) {
		return;
	}

	uint count, dummy;
	vertexBuffer.GetDimensions(count,dummy);
	
	uint srcIndex = dtid.x % count;
	uint dstIndex = dtid.y % count;

	float3 src = vertexBuffer[srcIndex];
	float3 dst = vertexBuffer[dstIndex];
	float dist = distance(src, dst);
	float alpha = calcAlpha(dist);

	if (alpha > 0) {
		LineConnection result;
		result.srcIndex = srcIndex;
		result.dstIndex = dstIndex;
		result.srcVertex = src;
		result.dstVertex = dst;
		result.distance = dist;
		result.alpha = alpha;
		Output.Append(result);
	}
}

technique11 Distance
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS() ) );
	}
}
