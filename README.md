# Compatibility-Guided Neighbor Selection (CGNS)

## Overview

This repository contains the implementation for the HPG 2026 paper:

> **Compatibility-Guided Neighbor Selection for ReSTIR**<br>
> Orion Junkins, Markus Kettunen, Daqi Lin, Ravi Ramamoorthi, and Chris Wyman<br>
> *Proc. ACM Comput. Graph. Interact. Tech.* 9, 4, Article 52 (July 2026)<br>
> [doi:10.1145/3820024](https://doi.org/10.1145/3820024)

**[Project page](https://orion-junkins.github.io/CGNS/)**

CGNS improves the spatial resampling step of ReSTIR [[Bitterli et al. 2020]](https://research.nvidia.com/publication/2020-07_spatiotemporal-reservoir-resampling-real-time-ray-tracing-dynamic-direct) by selecting neighbors proportional to their geometric compatibility. For each pixel, K candidates are drawn from a quasi-random disk and scored with a heuristic compatibility measure. This measure captures the similarity of primary hit positions and normals. From these K candidates, M are selected proportional to their compatibility via weighted reservoir sampling and passed directly to the spatial resampling pass. This compatibility guided neighbor selection replaces the uniform disk sampling of prior work, improving the *quality* of spatial neighbors with minimal runtime overhead.

This code is built on top of the Reservoir Splatting implementation of Jeffrey Liu [[Liu et al. 2025]](https://github.com/Jebbly/Reservoir-Splatting), a ReSTIR path tracer implementing GRIS [[Lin et al. 2022]](https://research.nvidia.com/publication/2022-07_generalized-resampled-importance-sampling-foundations-restir) with forward-reprojection-based temporal resampling. The renderer runs on top of the Falcor 8.0 framework [[Kallweit et al. 2022]](https://github.com/NVIDIAGameWorks/Falcor).

All CGNS-specific code lives in `Source/RenderPasses/CGNS/`. Key files:

| File | Purpose |
|------|---------|
| `CGNSUtils.slang` | Compatibility scoring heuristic (`computeNeighborWeight`) |
| `GenerateCGNSGBuffer.cs.slang` | Per-pixel G-buffer: world normal + cam distance |
| `WRSReservoir.slang` | A-Chao (used when M=1) and A-ES (used when M>1) WRS structs |
| `SelectNeighbors.cs.slang` | Scores K candidates, writes M selected neighbors for each pixel |
| `SpatialResampling.rt.slang` | Spatial RT pass, now reads pre-selected neighbors |

## Building and Running

Clone with submodules:

```
git clone --recursive https://github.com/orion-junkins/ReSTIR-CGNS.git
```

For build prerequisites and Falcor setup, see [Falcor's documentation](https://github.com/NVIDIAGameWorks/Falcor/blob/master/README.md). After building Mogwai, run `scripts/CGNS.py` to set up the render graph.

CGNS parameters are exposed under `CGNS → ReSTIR Options → Spatial Resampling → CGNS Neighbor Selection` in the UI.

## References

This code directly builds on the following prior work:

- **Bitterli et al. 2020** — Spatiotemporal Reservoir Resampling for Real-Time Ray Tracing with Dynamic Direct Lighting. *SIGGRAPH 2020*. [doi:10.1145/3386569.3392481](https://doi.org/10.1145/3386569.3392481)
- **Chao 1982** — A General Purpose Unequal Probability Sampling Plan. *Biometrika* 69(3):653–656. [doi:10.1093/biomet/69.3.653](https://doi.org/10.1093/biomet/69.3.653)
- **Efraimidis & Spirakis 2006** — Weighted Random Sampling with a Reservoir. *Inf. Process. Lett.* 97(5). [doi:10.1016/j.ipl.2005.11.003](https://doi.org/10.1016/j.ipl.2005.11.003)
- **Efraimidis 2015** — Weighted Random Sampling over Data Streams. *Algorithms, Probability, Networks, and Games*, LNCS 9295, pp. 183–195. [doi:10.1007/978-3-319-24024-4_12](https://doi.org/10.1007/978-3-319-24024-4_12). Sections covering A-Chao and A-ES provide our naming conventions and clearest presentation of the WRS algorithms used in this codebase.
- **Kallweit et al. 2022** — Falcor. [[Code]](https://github.com/NVIDIAGameWorks/Falcor)
- **Keller et al. 2016** — Path Space Filtering. *Monte Carlo and Quasi-Monte Carlo Methods*, SPMS 163, pp. 423–436. [doi:10.1007/978-3-319-33507-0_21](https://doi.org/10.1007/978-3-319-33507-0_21)
- **Lin et al. 2022** — Generalized Resampled Importance Sampling: Foundations of ReSTIR. *SIGGRAPH 2022*. [doi:10.1145/3528223.3530158](https://doi.org/10.1145/3528223.3530158)
- **Liu et al. 2025** — Reservoir Splatting for Temporal Path Resampling and Motion Blur. *SIGGRAPH 2025*. [doi:10.1145/3721238.3730646](https://doi.org/10.1145/3721238.3730646) [[Code]](https://github.com/Jebbly/Reservoir-Splatting)
- **Roberts 2018** — The Unreasonable Effectiveness of Quasirandom Sequences. [extremelearning.com.au](https://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/)
- **Shirley & Chiu 1997** — A Low Distortion Map Between Disk and Square. *Journal of Graphics Tools* 2(3):45–52. [doi:10.1080/10867651.1997.10487479](https://doi.org/10.1080/10867651.1997.10487479)
- **Zhang et al. 2024** — Area ReSTIR: Resampling for Real-Time Defocus and Antialiasing. *SIGGRAPH 2024*. [doi:10.1145/3658210](https://doi.org/10.1145/3658210)

See the full references list in the paper for all related work.