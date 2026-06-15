/**
 * Generates a per-pixel G-buffer for neighbor selection.
 * Reads the V-buffer and writes (world normal xyz, camera-to-surface distance) into
 * an RGBA16F texture consumed by SelectNeighbors.cs.slang.
 *
 * dist == 0 encodes an environment/invalid hit — SelectNeighbors and
 * CGNSUtils rely on this sentinel to detect the env-hit case.
 */

import Scene.Scene;
import Scene.HitInfo;
import LoadShadingData;
import Params;

struct GenerateCGNSGBuffer
{
    PathTracerParams params;

    Texture2D<PackedHitInfo> vbuffer;
    RWTexture2D<float4>      cgnsGBuffer;  ///< Output: (world normal xyz, cam-dist)

    void execute(const uint2 pixel)
    {
        if (any(pixel >= params.frameDim)) return;

        HitInfo hit = HitInfo(vbuffer[pixel]);

        if (!hit.isValid())
        {
            cgnsGBuffer[pixel] = float4(0, 0, 0, 0);  // dist == 0 → env hit
            return;
        }

        float3 cameraPos = gScene.camera.getPosition();
        ShadingData sd   = loadShadingData(hit, cameraPos, float3(0, 0, 1));
        float posDist    = distance(cameraPos, sd.posW);

        cgnsGBuffer[pixel] = float4(sd.frame.N, posDist);
    }
}

cbuffer CB
{
    GenerateCGNSGBuffer gGenerateCGNSGBuffer;
}

[numthreads(16, 16, 1)]
void main(uint3 dispatchThreadId : SV_DispatchThreadID)
{
    gGenerateCGNSGBuffer.execute(dispatchThreadId.xy);
}
