/**
 * Pre-selects M neighbors per pixel for spatial resampling.
 *
 * Directly implements Algorithm 1 (paper §5).
 *
 * Samples K candidates from the precomputed R2 quasi-random disk.
 * Scores each using the CGNS compatibility heuristic (CGNSUtils.slang).
 * Selects M via weighted reservoir sampling (WRSReservoir.slang).
 *
 * Output: neighborSelections[linearizePixel(px) * M + i] = selected int2 neighbors for pixel i.
 */

import Scene.Scene;
import Utils.Sampling.TinyUniformSampleGenerator;
import CGNSUtils;
import WRSReservoir;
import Params;

struct SelectNeighbors
{
    PathTracerParams params;

    Texture2D<float4>        cgnsGBuffer;           // (world normal xyz, cam-dist); dist==0 -> env hit
    Texture1D<float2>        neighborOffsets;       // R2 quasi-random disk offsets
    RWStructuredBuffer<int2> neighborSelections;    // Output: M selected pixels per pixel (stride = gM)

    float gGatherRadius;             // Radius for sampling neighbors 
    int   gM;                        // M - selections to return (1 -> A-Chao, >1 -> A-ES)
    int   gNeighborCandidateCount;   // K — candidates scored per pixel
    int   gSpatialRoundId;           // Current reuse round if multiple are enabled

    float gScaleSolidAngle;    // Ω (sr); controls position falloff radius via s = sqrt(Ω/π) * queryDist
    float gNormalBeta;         // β: exponent on max(n·n', 0)

    bool gUseEarlyStopping;     // Stop candidate sampling once M candidates with score >= gEarlyStopCutoff are found (paper §5, §7.5)
    float gEarlyStopCutoff;     // Determines threshold for early stopping

    float3 computeWorldPos(int2 px, float dist)
    {
        float3 dir = normalize(gScene.camera.computeNonNormalizedRayDirPinhole(uint2(px), params.frameDim));
        return gScene.camera.getPosition() + dir * dist;
    }

    float scoreCandidate(
        bool   queryValid,
        float3 queryPos,
        float3 queryNormal,
        float  queryScale,
        int2   candidatePx
    ) {
        float4 buf              = cgnsGBuffer[candidatePx];
        float3 candidateNormal  = buf.xyz;
        float  candidateDist    = buf.w;
        bool   candidateValid   = candidateDist > 0.0f;
        float3 candidatePos     = candidateValid
            ? computeWorldPos(candidatePx, candidateDist) : float3(0, 0, 0);

        return computeNeighborWeight(
            queryValid, candidateValid,
            queryPos, queryNormal,
            candidatePos, candidateNormal,
            queryScale, gNormalBeta
        );
    }

    void execute(uint2 pixel)
    {
        if (any(pixel >= params.frameDim)) return;
        uint centralOffset = params.linearizePixel(pixel);

        // Basic random seed, unique from other passes
        uint seed = (params.useFixedSeed > 0) ? params.fixedSeed + 4 : kNumRenderPasses * (params.frameCount + params.seed) + 1337 * uint(gSpatialRoundId) + 4;
        var sg = TinyUniformSampleGenerator(pixel, seed);

        float4 qBuf         = cgnsGBuffer[pixel];
        float3 queryNormal  = qBuf.xyz;
        float  queryDist    = qBuf.w;
        bool   queryValid   = queryDist > 0.0f;
        float3 queryPos     = queryValid ? computeWorldPos(int2(pixel), queryDist) : float3(0, 0, 0);
        float  queryScale   = computeNeighborScale(gScaleSolidAngle, queryDist);

        uint startIndex = uint(sampleNext1D(sg) * kSpatialNeighborSamples);
        uint base       = centralOffset * uint(gM);

        if (gM == 1)
        {
            // A-Chao WRS algorithm is simplest for M=1
            AChaoReservoir res;
            res.init(int2(pixel));

            for (int k = 0; k < gNeighborCandidateCount; k++)
            {
                int2 candidate = int2(round(float2(pixel)
                    + gGatherRadius * neighborOffsets[(startIndex + uint(k)) % kSpatialNeighborSamples]));
                if (!params.validateIntegerPixelBounds(candidate)) continue;

                float score = scoreCandidate(queryValid, queryPos, queryNormal, queryScale, candidate);
                float u     = sampleNext1D(sg);
                res.tryUpdate(candidate, score, u);

                if (gUseEarlyStopping && score >= gEarlyStopCutoff) break;
            }

            neighborSelections[base] = res.get();
        }
        else
        {
            // A-ES: key = log(u)/w per candidate, maintain top-M. Unbiased for any M.
            AESReservoir res;
            res.init(int2(pixel), uint(gM));

            int highQualityCount = 0;
            for (int k = 0; k < gNeighborCandidateCount; k++)
            {
                int2 candidate = int2(round(float2(pixel)
                    + gGatherRadius * neighborOffsets[(startIndex + uint(k)) % kSpatialNeighborSamples]));
                if (!params.validateIntegerPixelBounds(candidate)) continue;

                float score = scoreCandidate(queryValid, queryPos, queryNormal, queryScale, candidate);
                float u     = sampleNext1D(sg);
                res.tryUpdate(candidate, score, u, uint(gM));

                if (gUseEarlyStopping && score >= gEarlyStopCutoff)
                {
                    if (++highQualityCount >= gM) break;
                }
            }

            for (uint j = 0; j < uint(gM); j++)
            {
                neighborSelections[base + j] = res.get(j);
            }
        }
    }
}

cbuffer CB
{
    SelectNeighbors gSelectNeighbors;
}

[numthreads(16, 16, 1)]
void main(uint3 dispatchThreadId : SV_DispatchThreadID)
{
    gSelectNeighbors.execute(dispatchThreadId.xy);
}
