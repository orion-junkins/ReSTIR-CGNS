/**
 * Pre-selects M=1 neighbor pixel per pixel for spatial resampling.
 *
 * Samples K candidates from the R2 quasi-random disk, scores each using
 * the CGNS compatibility heuristic (CGNSUtils.slang), and selects one
 * via A-Chao weighted reservoir sampling.
 *
 * Output: neighborSelections[linearizePixel(px)] = selected int2 pixel.
 * The RT pass still picks neighbors randomly until Commit 4 wires this up.
 */

import Scene.Scene;
import Utils.Sampling.TinyUniformSampleGenerator;
import CGNSUtils;
import WRSReservoir;
import Params;

struct SelectNeighbors
{
    PathTracerParams params;

    Texture2D<float4>        cgnsGBuffer;       ///< (world normal xyz, cam-dist); dist==0 → env hit
    Texture1D<float2>        neighborOffsets;   ///< R2 quasi-random disk offsets
    RWStructuredBuffer<int2> neighborSelections;///< Output: one selected pixel per pixel

    int   gSpatialRoundId;
    int   gNeighborCandidateCount;   ///< K — candidates scored per pixel
    int   gM;                        ///< M — selections to keep (1 → A-Chao, >1 → A-ES)
    uint  gStride;                   ///< Elements per pixel in neighborSelections (== M)
    float gGatherRadius;

    float gScaleSolidAngle;    ///< Ω (sr); controls position falloff radius via s = sqrt(Ω/π) * queryDist

    bool  gUseNeighborRejection;
    float gEarlyStopCutoff;

    float3 computeWorldPos(int2 px, float dist)
    {
        float3 dir = normalize(gScene.camera.computeNonNormalizedRayDirPinhole(uint2(px), params.frameDim));
        return gScene.camera.getPosition() + dir * dist;
    }

    float scoreCandidate(
        bool   queryValid,
        float3 queryPos,
        float3 queryNormal,
        float  queryDist,
        int2   candidatePx
    ) {
        float4 buf            = cgnsGBuffer[candidatePx];
        float3 candidateNorm  = buf.xyz;
        float  candidateDist  = buf.w;
        bool   candidateValid = candidateDist > 0.0f;
        float3 candidatePos   = candidateValid
            ? computeWorldPos(candidatePx, candidateDist) : float3(0, 0, 0);

        return computeNeighborWeight(
            queryValid, candidateValid,
            queryPos, queryNormal, queryDist,
            candidatePos, candidateNorm, candidateDist,
            gScaleSolidAngle
        );
    }

    void execute(uint2 pixel)
    {
        if (any(pixel >= params.frameDim)) return;
        uint centralOffset = params.linearizePixel(pixel);

        uint seed = kNumRenderPasses * (params.frameCount + params.seed)
                  + 1337u * uint(gSpatialRoundId) + 42u;
        var sg = TinyUniformSampleGenerator(pixel, seed);

        float4 qBuf      = cgnsGBuffer[pixel];
        float3 queryNorm = qBuf.xyz;
        float  queryDist = qBuf.w;
        bool   queryValid = queryDist > 0.0f;
        float3 queryPos  = queryValid ? computeWorldPos(int2(pixel), queryDist) : float3(0, 0, 0);

        uint startIndex = uint(sampleNext1D(sg) * kSpatialNeighborSamples);
        uint base       = centralOffset * gStride;

        if (gM == 1)
        {
            // A-Chao: O(1) memory, unbiased for M=1.
            AChaoReservoir res;
            res.init(int2(pixel));

            for (int k = 0; k < gNeighborCandidateCount; k++)
            {
                int2 candidate = int2(round(float2(pixel)
                    + gGatherRadius * neighborOffsets[(startIndex + uint(k)) % kSpatialNeighborSamples]));
                if (!params.validateIntegerPixelBounds(candidate)) continue;

                float score = scoreCandidate(queryValid, queryPos, queryNorm, queryDist, candidate);
                float u     = sampleNext1D(sg);
                res.tryUpdate(candidate, score, u);

                if (gUseNeighborRejection && score >= gEarlyStopCutoff) break;
            }

            neighborSelections[base] = res.get();
        }
        else
        {
            // A-ES: key = log(u)/w per candidate, maintain top-M. Unbiased for any M.
            AESReservoir res;
            res.init(int2(pixel), uint(gM));

            for (int k = 0; k < gNeighborCandidateCount; k++)
            {
                int2 candidate = int2(round(float2(pixel)
                    + gGatherRadius * neighborOffsets[(startIndex + uint(k)) % kSpatialNeighborSamples]));
                if (!params.validateIntegerPixelBounds(candidate)) continue;

                float score = scoreCandidate(queryValid, queryPos, queryNorm, queryDist, candidate);
                float u     = sampleNext1D(sg);
                res.tryUpdate(candidate, score, u, uint(gM));

                if (gUseNeighborRejection && score >= gEarlyStopCutoff) break;
            }

            for (uint j = 0; j < uint(gM); j++)
                neighborSelections[base + j] = res.get(j);
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
