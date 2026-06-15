/**
 * Compatibility scoring for spatial neighbor selection.
 * Used by SelectNeighbors.cs.slang to score candidate pixels before WRS selection.
 *
 * Heuristic: h = h_position * h_normal (paper §4.3)
 *   h_position = exp(-||x - y|| / s)^positionBeta,  s = visibilityScaleFactor * queryDist
 *   h_normal   = max(n_x · n_y, 0)^normalBeta
 *
 * Paper defaults:  visibilityScaleFactor = sqrt(0.05/π) ≈ 0.1261,  normalBeta = 8,  positionBeta = 1
 */

#ifndef EPSILON
#define EPSILON 1e-8f
#endif

float computeNeighborWeight(
    bool   queryValid,
    bool   candidateValid,
    float3 queryPos,
    float3 queryNormal,
    float  queryDist,
    float3 candidatePos,
    float3 candidateNormal,
    float  candidateDist,
    float  gVisibilityScaleFactor,
    float  gPositionBeta,
    float  gNormalBeta
)
{
    if (!queryValid && !candidateValid)
        return 0.1f;   // both env hits — encourage reuse

    if (!queryValid || !candidateValid)
        return EPSILON; // one surface, one env — discourage

    // s = visibilityScaleFactor * d  (world-space scale, see Paper Section 4.3)
    float scale        = max(EPSILON, gVisibilityScaleFactor * queryDist);
    float positionScore = exp(-distance(queryPos, candidatePos) / scale);
    float normalScore   = max(0.0f, dot(queryNormal, candidateNormal));

    float weight = pow(positionScore, gPositionBeta) * pow(normalScore, gNormalBeta);
    return clamp(weight, EPSILON, 1.0f);
}
