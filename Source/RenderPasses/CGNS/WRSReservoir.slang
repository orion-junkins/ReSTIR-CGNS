/**
 * Weighted Reservoir Sampling structs for CGNS neighbor selection.
 *
 * AChaoReservoir: A-Chao [Chao 1982, see Efraimidis 2015] - running weight sum, probabilistic accept. M=1 only.
 *
 * AESReservoir: A-ES [Efraimidis & Spirakis 2006, see Efraimidis 2015] - key = log(u)/w per candidate, maintain
 *  top-M by evicting the minimum-key slot. Correct for any M.
 *  Implemented with a fixed array of 5 slots (M = 1..5). Increase allocation for M>5.
 *  Decrease allocation to improve performance for a specific count 2 <= M <= 5.
 */

#ifndef EPSILON
#define EPSILON 1e-8f
#endif

// ---------------------------------------------------------------------------
// A-Chao: probabilistic accept on running weight sum.
// ---------------------------------------------------------------------------
struct AChaoReservoir
{
    int2  selected;
    float weightSum;

    [mutating] void init(int2 initialItem)
    {
        selected  = initialItem;
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
// Fixed capacity of 5 slots (M <= 5)
// only activated when M > 1
// ---------------------------------------------------------------------------
struct AESReservoir
{
    static const uint kMaxCapacity = 5;

    int2  pixels[kMaxCapacity];
    float keys[kMaxCapacity];

    [mutating] void init(int2 initialItem, uint M)
    {
        for (uint i = 0; i < M; i++)
        {
            pixels[i] = initialItem; // Note: all items default to the initial, K < M leads to duplicates
            keys[i]   = -1e38f;
        }
    }

    // Returns true if candidate was inserted (evicted a previous slot).
    [mutating] bool tryUpdate(int2 candidate, float score, float u, uint M)
    {
        float key    = log(max(u, EPSILON)) / max(score, EPSILON);
        uint  minIdx = 0;
        float minKey = keys[0];

        // Linear probe; can be optimized with a min heap for larger M.
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

    int2 get(uint i) { return pixels[i]; }
}
