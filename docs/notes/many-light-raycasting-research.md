# Scaling visibility across many lights

Historical geometry note (2026-10-19): [ADR-0015](../adr/0015-use-colliders-for-foreground-fading.md) removes all alpha-derived fade geometry, SpriteGeometry, generated occluder assets, and their tasks/dependencies. Fading uses active wall/door colliders plus full artwork rectangles; lighting uses active object colliders under ADR-0014. Pipeline instructions, silhouette-specific behavior, and measurements below describe earlier implementations. Current setup is in [README](../../README.md), and current behavior is in [CONTEXT](../../CONTEXT.md).

Research date: 2026-10-18. Proposal and source evidence; no replacement algorithm is implemented by this note. Keep [HD disabled](../adr/0013-keep-hd-disabled.md), the current generated [occluders](../adr/0012-continuous-occluder-queries.md), and the user's exclusion of rotational sweep. See the [native audit and measurements](many-light-raycasting-audit.md); published C/C++/GPU results do not predict DragonRuby Ruby timings.

## Architectural work comes first

Inspection of [Room](../../mygame/app/room.rb), [RoomPreview](../../mygame/app/room_preview.rb), and [Raycasting](../../mygame/app/raycasting.rb) establishes these current behaviors:

- `Room#render_data` transforms every blocker into world-space edges on every call, including frames without lighting diagnostics. Membership is cached; geometry is not.
- Diagnostics cast only the player's lamp. Room sources are markers. The lamp helper reconstructs endpoint hashes, selects blockers, builds angle buckets, casts rays, sorts hits, and allocates outline lines each time.
- Room sources already declare `ignore_owner_ids`, but the lamp helper does not consume it. An all-source trial must document its selection and apply the intended owner exclusions; a mounted source intersecting its own support can produce cheap but misleadingly blocked output. The audit also applies the guide's 96-unit fallback to authored zero radii.
- Flame animation changes active occluder geometry. A stationary emitter is therefore not necessarily an unchanged visibility query. Door variants, light toggles, placement transforms, exclusions, and room reload also matter. Camera movement does not change world-space geometry.

**Inference:** Many-source scaling should first remove repeated unchanged work and distinguish geometry solving from debug-line submission. Moving the same work into a new module cannot itself improve performance. A dirty flag is an established mechanism for deferring derived-data updates until an input changes, with invalidation correctness and retained memory as explicit costs. [Nystrom's original chapter](https://raw.githubusercontent.com/munificent/game-programming-patterns/master/book/dirty-flag.markdown)

There is relevant contrary evidence: [ADR-0009](../adr/0009-measured-render-preparation.md#4-prepared-geometry-candidate--removed) rejected an earlier transformed-geometry cache for foreground fading after its measurements failed. Lighting now transforms all blockers and may query many sources, so this is a different experiment, not permission to restore the old design unquestioned. Keep `SpriteGeometry` stateless; any retained lighting geometry should belong to the Room's lighting data or a narrow lighting consumer.

## Why angular buckets eventually run out of room

This is analysis of our code, not a published bound on all bucket algorithms. For one source let `N` be selected segments, `R` the three-per-unique-endpoint rays, and `C(ray)` its bucket's candidate count. Current work includes bucket preparation, `sum(C(ray))` exact intersection attempts, and sorting `R` hits. Bucket membership depends on source position, so another source needs another index. No distance ordering lets a ray stop after its first nearby obstruction.

With fixed 64 buckets, many overlapping angular spans can put most segments in the same candidate lists. Worst-case intersection work remains `O(R*N)` per source; where `R` grows with `N`, that is quadratic. Increasing bucket count improves angular discrimination only: overlapping walls in the same direction still remain candidates. For unchanged stationary sources, reusing the complete polygon can avoid this work regardless of which index built it.

## Established alternatives

| Technique | Primary-source mechanism | Adaptation judgment |
| --- | --- | --- |
| Shared uniform grid plus Amanatides–Woo traversal | Store primitives in overlapping cells; advance through cells in ray order. The paper starts with the 2D derivation, handles duplicate primitive tests with ray IDs, and requires checking the hit against the current cell exit before stopping. [Original paper](https://www.eecs.yorku.ca/~amana/research/grid.pdf) | **First algorithm prototype.** World-cell membership is shared across lights. Preserve Case's endpoint rays and nearest-hit math. A sparse hash keyed by integer cell coordinates changes storage, not the traversal algorithm. Cell size trades candidate density against traversal overhead; large radii and empty regions can be expensive. |
| Shared BVH | Group primitives hierarchically; a missed parent box rejects an entire subtree. Each primitive appears once, avoiding cell duplication. PBRT documents build-quality versus build-time choices. [PBRT](https://www.pbr-book.org/4ed/Primitives_and_Intersection_Acceleration/Bounding_Volume_Hierarchies) | **Second prototype if grid measurements disappoint.** A static median-split BVH plus a small dynamic list is simpler than porting a complete dynamic tree. Long segments and uneven spatial density may favor this structure; Ruby node traversal can still cost more than the saved tests. |
| Dynamic AABB tree | Box2D's balanced tree supports region queries and ray queries; exact geometry stays in the caller. Ray callbacks can shorten the search interval after a hit. [Box2D tree documentation](https://box2d.org/documentation/group__tree.html) | Established for mutable worlds, but insertion/removal, balancing and bounds updates add substantial machinery. Reserve it for numerous moving blockers, rather than importing a physics engine for this room. |

A hierarchy differs materially from the discarded sprite-box loop: it can skip many sprites at one node. A grid also differs from merely fetching local edges and scanning them: DDA visits cells near-to-far and can stop before reaching distant geometry. Red Blob explicitly identifies spatial hashing as a way to accelerate endpoint-directed visibility rays before presenting its separate sweep alternative. [Author's visibility explanation](https://www.redblobgames.com/articles/visibility/#wall-tracking)

None of these structures removes endpoint generation or sorting, nor guarantees sublinear ray queries in every arrangement. Preserve buckets as the measured control. A useful intermediate grid experiment is sharing radius queries across lights while retaining buckets; replacing ray candidate selection with DDA should be a separate comparison.

## Correctness obligations for the grid experiment

These are proposed implementation requirements, not a claim that the original paper covers every project edge case:

- Index conservative world bounds or all touched cells, including edges crossing a light's bounds with both endpoints outside. Retain exact segment intersections; cells must not become solid tile-shaped blockers.
- Use stable segment IDs and per-ray visitation stamps across **all** lights. A segment spanning cells should be tested once; retain its discovered hit even if it lies in a later cell. Stop only when no unvisited cell can contain a nearer hit.
- Specify inclusive boundary and corner handling. Horizontal/vertical rays, negative coordinates, origins on cell boundaries, exact corner crossings, and source-on-segment cases need tests. Conservative insertion into touching cells or explicit supercover traversal must prevent boundary-only geometry from disappearing.
- Respect each source's range and owner exclusions in endpoint collection and hit queries. Keep border termination consistent with the current square envelope; this is not permission to change radial falloff or silhouettes.
- Keep disconnected and concave outlines and overlapping sprites. Per-ray exact intersection tests need no convex decomposition, but preserving endpoint sampling also preserves its limitations: an acceleration structure does not repair missing visibility events at segment crossings.
- A viewport can select lights whose influence reaches the screen; it cannot select blockers solely by whether their sprites are on screen. Record full-room stress results separately from visible-influence results.

## Reuse and invalidation proposal

Prioritize whole-polygon reuse: the native audit measured about 34 ms for seven solves versus 0.8 ms for fresh room data, and sharing endpoint conversion saved only about 0.2 ms. Static transformed-geometry caching is therefore a secondary experiment, not a prerequisite. If later justified, prepare immutable world edges and direction differences once for static placed sprites; update a door or animated variant only when its shape changes. Origin-relative offsets and angle buckets remain source-dependent. Stable placement/variant identities can avoid rebuilding equivalent geometry, but confirm actual geometry changes rather than assuming every texture frame differs.

Cache each light's world-space polygon against position, radius, owner exclusions, and relevant blocker changes. Changes to color or intensity affect composition, not this polygon. Begin with conservative invalidation; refine to old **and** new changed-blocker bounds overlapping the source range only if broad invalidation is measurably expensive. Newly introduced blockers must invalidate queries even when absent from the former candidate set. Reload clears room-owned state. These are project-specific applications of [dirty derived data](https://raw.githubusercontent.com/munificent/game-programming-patterns/master/book/dirty-flag.markdown).

Other lights' animated silhouettes currently block rays. Do not silently exclude flames to improve cache hit rates: that changes the lighting model and needs a separate decision. Likewise, do not merge geometry across ownership groups merely to remove duplicate edges.

## GPU alternatives and SDK fit

A documented shader approach renders an occlusion texture, reduces it to nearest blocker distance per angle in a 1D shadow map, then shades from that map. Its author explicitly discusses multiple passes, fill rate and sampling precision; this is not an automatic speedup. [DesLauriers' implementation](https://github.com/mattdesl/lwjgl-basics/wiki/2D-Pixel-Perfect-Shadows)

Installed DragonRuby 7.21 documentation was consulted first: `$DRAGONRUBY_HOME/docs/api/outputs.md` documents custom shaders as Indie/Pro features, while triangles, render targets and blend modes are ordinary output facilities. Its `13_lighting` sample demonstrates composition; `21_line_of_sight` explicitly uses rotational sweep and therefore is not a candidate here. Standard's available primitives can render a computed polygon, but do not provide the custom shader required by the cited 1D implementation. Cached targets require care: accessing `args.outputs[target]` invalidates their texture. [Official outputs reference](https://docs.dragonruby.org/#/api/outputs)

## Ordered experiment

1. Measure all enabled sources plus the player, with owner exclusions documented: selection/preparation, ray kernel, output construction and rendered playback separately. Include stationary, moving-player, animated-flame and door-change cases; report recomputation counts and peak frames as well as medians.
2. Compare unchanged-result reuse and static-edge reuse independently, keeping buckets. Establish whether query frequency or exact intersections dominate before adding an index.
3. Prototype a shared grid for radius queries, then DDA ray traversal, preserving rays and geometry. Compare total cost including index build/update, with several cell sizes, source counts and radii. Record cells visited, unique segments tested and candidate counts; fewer intersections alone is insufficient evidence.
4. Try a static BVH only if grid density, long edges or empty-cell traversal demonstrably dominate. Defer dynamic-tree and GPU redesigns until the simpler measured alternatives fail.

Acceptance: equivalent nearest-hit geometry against the flat reference on numerical/ownership/variant cases; repeatable whole-workload savings exceeding host variation; manageable invalidation and code size. Keep HD off throughout. Reuse may win the steady state while rebuild spikes still exceed a frame budget, so benchmark both.
