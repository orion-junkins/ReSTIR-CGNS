/**
 * Weighted Reservoir Sampling structs for CGNS neighbor selection.
 *
 * WRS_ALG_ACHAO (0): A-Chao (Efraimidis 2010, Algorithm A-Chao, Sec 3.1) — running weight sum,
 *                    probabilistic accept. Used for M=1. For M>1, overweight items
 *                    (w_i > W_{i-1}) are selected with probability 1, which biases
 *                    the sample when multiple slots must be filled independently.
 * WRS_ALG_AES   (1): A-ES (Efraimidis 2010, Algorithm A-ES, Sec 3.2) — key = log(u)/w per
 *                    candidate, maintain top-M by evicting the minimum-key slot.
 *                    Correct for any M. Fixed array of 5 slots (M = 1..5).
 */

#define WRS_ALG_ACHAO 0
#define WRS_ALG_AES   1

/// Stride used when writing/reading the neighborSelections buffer.
/// Always kWRSMaxCapacity regardless of active M, so the layout is stable.
static const uint kWRSMaxCapacity = 5;

#ifndef EPSILON
#define EPSILON 1e-25f
#endif

// ---------------------------------------------------------------------------
// A-Chao: probabilistic accept on running weight sum. M=1 only.
// ---------------------------------------------------------------------------
struct AChaoReservoir
{
    int2  selected;
    float weightSum;

    [mutating] void init(int2 fallback)
    {
        selected  = fallback;
        weightSum = 0.0f;
    }

    // Returns true if candidate was selected.
    [mutating] bool tryUpdate(int2 candidate, float score, float u)
    {
        weightSum += score;
        if (weightSum > 0.0f && u < score / weightSum)
        {
            selected = candidate;
            return true;
        }
        return false;
    }

    int2 get() { return selected; }
}

// ---------------------------------------------------------------------------
// A-ES (Efraimidis-Spirakis): key = log(u)/w, maintain top-M.
// Fixed capacity of 5 slots (M <= 5). Defined here for future use;
// only activated when WRS_ALGORITHM == WRS_ALG_AES.
// ---------------------------------------------------------------------------
struct AESReservoir
{
    static const uint kMaxCapacity = 5;

    int2  pixels[kMaxCapacity];
    float keys[kMaxCapacity];

    [mutating] void init(int2 fallback, uint M)
    {
        for (uint i = 0; i < M; i++)
        {
            pixels[i] = fallback;
            keys[i]   = -1e38f;
        }
    }

    // Returns true if candidate was inserted (evicted a previous slot).
    [mutating] bool tryUpdate(int2 candidate, float score, float u, uint M)
    {
        float key    = log(max(u, EPSILON)) / max(score, EPSILON);
        uint  minIdx = 0;
        float minKey = keys[0];
        for (uint i = 1; i < M; i++)
        {
            if (keys[i] < minKey) { minKey = keys[i]; minIdx = i; }
        }
        if (key > minKey)
        {
            pixels[minIdx] = candidate;
            keys[minIdx]   = key;
            return true;
        }
        return false;
    }

    // Current eviction threshold: lowest key in the reservoir.
    float getThreshold(uint M)
    {
        float t = keys[0];
        for (uint i = 1; i < M; i++) t = min(t, keys[i]);
        return t;
    }

    int2 get(uint i) { return pixels[i]; }
}
