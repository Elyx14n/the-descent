# Raycasting optimization options

Research date: 2026-10-18. This is an options note, not an accepted replacement design. Preserve the user's reference vocabulary and public `get_intersection` / `get_sight_polygon` interfaces. Keep [HD disabled](../adr/0013-keep-hd-disabled.md); rendering cost and geometry cost are separate.

## What the reference does, and what we measured

[Nicky Case's Sight & Light](https://ncase.me/sight-and-light/) casts three rays per unique endpoint, selects each ray's nearest intersection, then sorts by angle. With endpoint count proportional to segment count, the all-pairs intersection work grows quadratically. Our temporary direction buckets change candidate selection; they preserve those rays and their precision. Think of sorting fences into directional trays before asking each laser which fences it could reach.

The [learning note](raycast-lighting.md#performance-checkpoint-before-filling-the-light) records the original roughly 300,000 pair tests per frame and existing range/preparation optimizations. A fresh local HD-off, offscreen moving-lamp comparison isolated bucket removal while retaining range filtering and numeric preparation:

| Window, B overlay on | With buckets: FPS / median preparation | Without: FPS / median preparation |
| --- | --- | --- |
| 640 × 360 | 63.58 / 11.322 ms | 31.20 / 30.454 ms |
| 1920 × 1080 | 62.62 / 11.868 ms | 33.19 / 28.925 ms |

These are short native playback observations, not general algorithm guarantees. The user's separate playtest without buckets reached about 40 FPS. The subsequent sprite-bounds and per-edge angular-span trials are measured in the [learning note](raycast-lighting.md#performance-checkpoint-before-filling-the-light). Buckets are now restored. Testing those filters alongside buckets found no clear complementary benefit, so both filters were removed; lamp-range filtering and prepared numeric intersections remain. The other options remain research only.

## Standard approaches, compared

The mechanisms below come from primary sources; complexity and suitability judgments are this project's adaptation inferences.

| Approach | Work avoided and source | Fit for this game |
| --- | --- | --- |
| **Bounds rejection and prepared numbers** | Bounding volumes reject whole groups before exact intersections; PBRT also precomputes reused ray values and uses compact data layouts. [PBRT](https://www.pbr-book.org/4ed/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies) | Keep existing lamp-square filtering and once-per-call segment preparation. Tested each ray against bounds derived from each blocker sprite’s actual edges before testing those edges. This helped without buckets, but adding it to buckets did not improve the measured workload; the per-ray bounds filter is removed. No persistent index required. Per-edge ray/box tests may cost more than they save; favor skipping groups. |
| **Reuse unchanged results** | A dirty flag defers recomputation until primary inputs change. [Author's Dirty Flag chapter](https://raw.githubusercontent.com/munificent/game-programming-patterns/master/book/dirty-flag.markdown) | An unchanged lamp and unchanged selected geometry can reuse a world-space polygon. This helps stationary sources, not a continuously moving lamp. Doors, active light-animation silhouettes, exclusions and reload must invalidate it. Camera movement alone need not. State tracking adds obligations absent from temporary buckets. |
| **Spatial grid/hash with ray traversal** | Amanatides–Woo advances through successive occupied-space cells and avoids repeated object tests; Red Blob explicitly suggests a spatial hash for visibility rays. [Original paper](https://www.eecs.yorku.ca/~amana/research/grid.pdf), [Red Blob](https://www.redblobgames.com/articles/visibility/#wall-tracking) | Keeps endpoint-directed rays. Index segments by world cells and visit only cells crossed by each ray. Requires cell sizing, duplicate suppression, axis/corner handling and safe nearest-hit termination. More machinery than current buckets; useful if room scale or light count grows. |
| **BVH / quadtree** | Box2D's hierarchical AABB tree supports region and ray queries that skip many shapes. [Box2D](https://box2d.org/documentation/md_collision.html) | Could serve radius queries and ray queries together. A BVH groups objects; a quadtree partitions space and must handle boundary-spanning segments. Build/update/traversal code exceeds a flat bounds pass and likely the present buckets. No reason to add a physics dependency. |
| **Rotational sweep** | Sort endpoints and maintain the currently intersected walls, emitting output when the nearest wall changes. CGAL documents an O(n log n) rotational sweep. [Red Blob](https://www.redblobgames.com/articles/visibility/#wall-tracking), [CGAL](https://doc.cgal.org/latest/Visibility_2/index.html) | Replaces repeated independent ray searches with an active-set algorithm. The user explicitly ruled this out for this PR; it is farther from Case's implementation. Ordering, ties and crossing segments make it a substantial rewrite rather than a simpler bucket replacement. |
| **Reduce geometry before casting** | Simplification trades vertex count against displacement; polygon union combines overlapping solids. [Shapely simplify](https://shapely.readthedocs.io/en/stable/reference/shapely.simplify.html), [union](https://shapely.readthedocs.io/en/stable/reference/shapely.union_all.html) | Exact duplicate removal or merging truly collinear adjacent edges may preserve silhouettes. Existing [occluders](../adr/0012-continuous-occluder-queries.md) are already simplified. Increasing tolerance changes shadows; union across sprites complicates ownership exclusions and animated variants. Do not assume union always reduces vertices. |

CGAL's **triangular expansion** traverses visible neighboring triangles after preprocessing a polygonal domain. Its published gains concern that representation and C++ implementation. Building an arrangement/triangulation from our overlapping, mutable sprites is considerably beyond this PR; those timings do not predict DragonRuby performance. [CGAL manual](https://doc.cgal.org/latest/Visibility_2/index.html)

## Measured choice and next options

1. **Restore buckets with lamp-range filtering and prepared numeric intersections.** Range filtering reduces geometry and endpoint rays before constructing the index; numeric preparation reduces work inside the exact intersection loop. They complement the index.
2. **Remove per-ray sprite bounds and exact edge-span filters.** An interleaved native comparison of all four bucket/filter combinations found no clear added value. Sprite bounds were slower in every tested position. Edge-span checks varied from roughly 1% faster to 4% slower. Combining both filters also cost more. The [learning note](raycast-lighting.md#performance-checkpoint-before-filling-the-light) records the complete comparison and method. The extra grouped interface and experimental implementations are removed.
3. Playtest the restored version before choosing another structure. A spatial grid/hash remains an option if room scale or light count eventually warrants it. Rotational sweep is excluded by the user.
4. Consider exact geometry cleanup only when measured; reserve result caching for repeated unchanged queries. Neither is needed to justify a framework now.

## Correctness and measurement gates

- Keep crossing segments even when both endpoints lie outside the lamp square. Use inclusive bounds; touching edges count. A bounding box is a conservative filter, never a substitute silhouette.
- Preserve disconnected components, concavities and emitter exclusions. Overlapping sprites introduce segment crossings; a sweep needs appropriate intersection events/splitting, and endpoint-only reference output is not a proof of complete geometric robustness.
- Compare each candidate against the same uncategorized prepared loop with identical segments, endpoint rays and tolerance. Include negative-angle wrap, fractional origins, source-on-edge, border crossings and active door/light variants.
- Measure polygon time separately from frame preparation and rendered FPS. Include candidate counts, pair tests and setup cost; use fixed room positions plus moving-lamp playback, warm-up and repeated samples. Keep HD off, window settings and overlay state identical. Retain a change only when its total benefit justifies its added explanation and maintenance.
