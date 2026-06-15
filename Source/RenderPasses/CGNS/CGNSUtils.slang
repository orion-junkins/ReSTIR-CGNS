/**
 * Compatibility scoring for spatial neighbor selection.
 * Used by SelectNeighbors.cs.slang to score candidate pixels before WRS selection.
 *
 * Heuristic: h = h_position * h_normal  (paper §4.3)
 *   h_position = exp(-||x - y|| / s),   s = sqrt(Ω/π) * queryDist
 *   h_normal   = max(n_x · n_y, 0)
 *
 * Ω (scaleSolidAngle, steradians) is the only tunable parameter.
 * Paper default: Ω = 0.05 sr.
 */

#ifndef EPSILON
#define EPSILON 1e-8f
#endif

static const float kPi = 3.14159265f;

float computeNeighborWeight(
    bool   queryValid,
    bool   candidateValid,
    float3 queryPos,
    float3 queryNormal,
    float  queryDist,
    float3 candidatePos,
    float3 candidateNormal,
    float  candidateDist,
    float  gScaleSolidAngle   ///< Ω in steradians; s = sqrt(Ω/π) * queryDist
)
{
    if (!queryValid && !candidateValid)
        return 1.0f;   // both env hits — encourage reuse

    if (!queryValid || !candidateValid)
        return EPSILON; // one surface, one env — discourage

    // s = sqrt(Ω/π) * d  (characteristic world-space radius at depth d, see Paper section 4.3)
    float scale         = max(EPSILON, sqrt(gScaleSolidAngle / kPi) * queryDist);
    float positionScore = exp(-distance(queryPos, candidatePos) / scale);
    float normalScore   = max(0.0f, dot(queryNormal, candidateNormal));

    return clamp(positionScore * normalScore, EPSILON, 1.0f);
}
