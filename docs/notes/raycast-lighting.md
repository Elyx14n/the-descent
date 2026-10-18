# Raycast lighting: guided implementation

Date: 2026-10-18; updated 2026-10-19. Status: guided implementation in progress; collider-base lighting and mask falloff are integrated; playtesting continues.

The PR's endpoint is a complete lighting system and test suite: authored room lights and a toggleable, circular player lamp, with sharp shadows and soft radial falloff. Implement it yourself in small commits, with quick checks and playtesting between them. Ask for focused help at the current checkpoint rather than working through a full solution up front.

The main references are Nicky Case's [Sight & Light guide](https://ncase.me/sight-and-light/) and the supplied HTML preserved in the [reference appendix](#reference-snippet). Follow their names and vocabulary while adapting the implementation to Ruby, upward-increasing world Y, and the game's camera/render targets. The supplied HTML is a user-provided variant; the guide also explores fuzzy shadows, which remain outside this PR.

## Collider bases and integrated lighting

The user accepted the one-wall experiment and chose active object colliders as ground-plane blocking bases throughout the normal room preview. [ADR-0014](../adr/0014-use-collider-bases-for-lighting.md) records that decision. Tall projected artwork and ceiling caps no longer supply floor-lighting silhouettes. Generated alpha outlines remain in use for foreground fading and magenta debug outlines; removing them would change fading, not merely lighting.

The [foreground-lighting research](foreground-lighting-research.md) explains caster/receiver separation and richer alternatives. Height-aware shadows are deferred: the accepted approximation shades foreground artwork from its base and leaves caps ambient.

### Wired learning checkpoint (2026-10-19)

Run the normal room:

```sh
bin/rake run
```

Use WASD to move, E for doors and room lights, F for the player lamp, B for diagnostics, and R to reload. There is no separate LightingPreview. The player radius is 64 world pixels; room lights default to 48, with positive authored overrides retained.

The handoffs are:

1. `Room#render_data` supplies enabled `light_sources`, one `light_blockers` record per active object collider, and `light_receivers` pairing artwork with its bases. Doors use active open/closed rectangles; mounted sources and receivers use their hosts. Colliderless artwork receives via its placement baseline without creating a caster.
2. `RoomPreview` appends the player's source at its foot-collider center and its receiving base. It calls stateless `Lighting.prepare(light_sources:, light_blockers:)` for `{ source:, sight_polygon: }` records. Each source excludes its own owner group and terminates rays on a 32-sided circular boundary. The surrounding square only selects nearby blockers.
3. `Lighting.triangles` builds a source-centered fan using `camera.to_screen` for the source and every boundary vertex, preserving fractional coordinates through drawing. `Lighting.draw_lightmap` prepares `:radial_light` from the existing mask alpha, then accumulates polygon-clipped illumination above RGB-31 ambient in `:lightmap`. Only afterward does Render create `:scene`, draw its floor, multiply the lightmap over that floor, and append the existing depth-sorted foreground. There is no separate `:lit_floor` target.
4. `Lighting.receiver_colors` samples the prepared polygons at object bases; `Lighting.tint` shades foreground RGB while preserving authored colors and fade alpha. Foreground faces carry `front_y`: sources behind that south-facing surface cannot brighten the whole sprite through an exposed side/corner. Top-down walls retain ordinary base sampling. Caps use ambient. HUD and diagnostics remain above lighting. B reuses the prepared player polygon for its red outline; magenta shows artwork geometry and yellow shows physical colliders.

Movement regressions exposed strict ray/segment endpoint rounding in the receiving check: a corner sample could alternate between lit and ambient. The angular search now selects the boundary edge and tests its inward side directly, avoiding another endpoint intersection. Centering the player source inside its foot collider prevents zero-distance hits at southern contact.

The floor now uses the supplied `sprites/light_mask.png` for soft radial falloff inside sharp sight-polygon boundaries. Foreground base samples retain their simple linear distance approximation. Detailed shadows across faces, finite heights, and actor shadow casting are deferred. The remaining checkpoint is visual tuning and regression playtesting, rather than another geometry algorithm.

The installed 7.21 triangle path uses an explicit texture/UV mapping and `blendmode_enum: 2` for additive contributions. Ordinary render-target sprites use `blendmode: 8` for multiplication. These verified paths differ; do not interchange blend property names blindly.

All-source integration initially measured about 30 FPS locally when recalculating seven polygons every frame. RoomPreview now owns one fixed-room cache keyed by source snapshots, collider bounds/ownership, and circle/default settings. Doors, source edits, and toggles invalidate it; successful reloads reset it. Animation, fading, and camera movement do not. The moving player source still recalculates each frame, and Lighting stays stateless. This is reuse of unchanged results, without a new raycasting algorithm or spatial index.

Integrated playback, Linux DragonRuby 7.21 Standard, HD off, offscreen software rendering, 30 warm-up / 60 measured frames per case:

| Window | Diagnostics | Uncached FPS / median Ruby preparation | Fixed-room reuse FPS / median Ruby preparation |
| --- | --- | --- | --- |
| 640×360 | Off | 31.59 / 28.385 ms | 62.87 / 10.430 ms |
| 640×360 | On | 27.46 / 33.018 ms | 59.86 / 13.028 ms |
| 1920×1080 | Off | 32.83 / 27.330 ms | 62.85 / 10.534 ms |
| 1920×1080 | On | 28.37 / 32.152 ms | 59.03 / 12.563 ms |

This probe moves the player with all six fixed room sources enabled; it does not stress repeated door toggles or cold-cache frames. These short local observations establish the value of reuse for this workload, not displayed FPS on the user's machine.

After the movement/contact/face-shading fixes, the same local probe measured 63.48 / 61.14 FPS with diagnostics off at 640×360 / 1920×1080 (median Ruby preparation 10.864 / 11.416 ms), and 57.58 / 52.37 FPS with diagnostics on (14.559 / 16.403 ms). Treat these as a later observation with the corrected source origin, not an isolated timing comparison of the receiving check. A separate rendered moving-lamp probe kept all 7,600 sampled interior-floor pixels fully illuminated across 19 consecutive frames; native tests cover continuous base illumination during fractional movement. Rendered southern-corner and wall/door-contact captures were also inspected. User confirmation of the reported scenarios remains pending.

Native coverage includes circle approximation, intersection/owner exclusions, camera conversion, floor/foreground composition, hidden receivers, color/intensity, lamp and door changes, cache invalidation, and reload recovery. The full suite passes 183 tests, including fractional-motion vertex sampling and lamp range at southern wall/door contact. `bin/rake run -- --eval tests/lighting_playback.rb` captures the normal room, closed/open door, player-lamp-off, all-lights-off, southern corner/wall/door contact, and isolated mounted-light on/off states under ignored `mygame/tmp/`. Those rendered captures were inspected locally; controls, readability, and displayed FPS still require playtesting.

### Diagonal sprite-edge jitter: a stale floor pass

The first attempted fix rounded triangle vertices to the artwork raster and discarded collapsed wedges. **That did not fix the reported jitter.** Both changes and their policy-specific tests were subsequently removed at the user's request. Triangle vertices now retain fractional coordinates; camera and artwork placement remain unchanged.

The user's isolation test was decisive: full lighting and floor-only lighting jittered; constant foreground tint and the unlit reference stayed stable, all with HD off. This ruled out foreground tinting and the HD-mode difference from master as sufficient explanations.

Inspection of installed SDK `docs/oss/dragon/args.rb` (`render_target`) and `runtime.rb` (`tick_gtk_engine_after`) established that passes execute in first-access order. Render created `:scene` before `:lightmap` and `:lit_floor`, so the current sprites were drawn over the previous frame's floor. A probe alternating red/green floor color reproduced the error every frame: odd frames expected green but displayed red, and even frames did the reverse. The one-frame camera mismatch was especially visible during diagonal movement around silhouettes.

The fix prepares the lightmap before creating `:scene`. The floor is drawn directly into `:scene` and multiplied before foreground sprites are appended, removing `:lit_floor` entirely. The same color probe now displays the current frame's color on every measured frame. A native regression verifies producer-before-consumer target access, and the existing composition/fade checks remain intact. With mask falloff enabled, order is `:radial_light → :lightmap → :scene → screen`. The mask pass is omitted when no lights are active. HD remains off, and camera/fade code is unchanged. The user confirmed that the corrected pass order resolved the diagonal jitter.

The temporary four-mode comparison playback was removed after diagnosis. The normal lighting playback and render-pass-order regression remain. After removing vertex rounding and wedge filtering, all 183 native tests and RuboCop pass. The alternating-color probe still displays the current floor on all seven sampled frames; room, southern-contact, and mounted-light captures were inspected. Fresh all-source software-rendered playback measured 53.04 / 61.78 FPS with diagnostics off and 57.03 / 56.01 FPS with diagnostics on at 640×360 / 1920×1080. These observations overlap the earlier mounted-light runs and do not establish a cleanup-specific speed change. Diagonal motion on the user's display remains the final regression check for this cleanup.

### Existing mask and radial falloff

The project's `light_mask.png` is byte-identical to the installed `13_lighting` sample mask: its RGB is black over the useful region and its radial profile lives in alpha. Multiplying its RGB by a light color cannot make it white. Instead, a 128×128 render target (matching the default player diameter) copies the original RGBA with blending disabled, then uses a white fill with `source RGB × destination alpha` and opaque output alpha. This produces RGB falloff suitable for additive illumination without squaring the alpha. It leaves the asset unchanged and adds no runtime image scanning, generated file, gem, or shader.

Each triangle samples that shared texture with UVs derived from its screen-space displacement from the source divided by the source diameter. The sight polygon remains the sharp shadow stencil. Authored color/intensity still modulate contributions; radii stay 64 for the player and fallback 48 for room sources. The mask improves the visual falloff, not the raycasting algorithm. Removing the intermediate floor pass reduces compositing work; measure the combined pipeline instead of attributing a speedup to the texture alone.

Completed-pass playback after the order fix and mask integration (same local Linux/offscreen software-rendered probe, 30 warm-up / 60 measured frames):

| Window | Diagnostics | FPS | Median Ruby preparation |
| --- | --- | ---: | ---: |
| 640×360 | Off | 63.93 | 9.052 ms |
| 640×360 | On | 61.85 | 11.230 ms |
| 1920×1080 | Off | 63.92 | 8.712 ms |
| 1920×1080 | On | 59.93 | 11.143 ms |

These include the mask pass, smaller triangle submission after raster collapse, and removal of the intermediate floor target; they do not isolate any one change. Mask falloff and contact captures were inspected, and 184 native tests plus RuboCop pass. The user confirmed that the diagonal jitter is fixed; brightness/falloff tuning remains a playtest check.

### Mounted lights and colliderless ledges

The Ritual Gate's lights 121/122 mount on decorative ledges 117/118, which have no colliders. Separate wall objects 22/80 occupy those cells. Projecting the lamp to the host baseline at Y=288 put the ray origin exactly on those walls' blocking edges: both lights generated zero drawable floor triangles while base sampling could still brighten their wall artwork.

`Room#light_sources` now places mounted origins one world pixel south/in front of the host base (Y=287 here). Their authored coordinates, owner exclusions, receiving bases, radii, and supporting-wall colliders stay intact. The wall still blocks rays toward the floor behind it; the fix does not add another wall ID to the emitter's exclusion list. Both sources now generate nonzero floor fans and illuminate the near floor. A native regression covers both lamps, near-floor samples on either side, host/support receiving colors, and far-floor rejection. The capture playback isolates both lamps, one off, and both off; these rendered states were inspected. Earlier performance probes with these source positions included two enabled but collapsed mounted polygons, so they did not exercise seven valid floor fills. The first corrected all-source software-rendered run measured 55.11 / 53.30 FPS with diagnostics off and 46.23 / 51.41 FPS with diagnostics on at 640×360 / 1920×1080; do not compare that host-sensitive observation to the earlier 60–64 FPS run as an isolated optimization result. A confirmation run measured 58.65 / 64.14 FPS with diagnostics off and 57.58 / 55.17 FPS with diagnostics on, showing substantial host variance without further code changes. Both runs now include valid floor illumination from the mounted sources; user hardware playback is the performance acceptance check.

## Building blocks and ownership

| Primitive | Meaning / analogy | Producer → consumer |
| --- | --- | --- |
| Line segment | A finite edge that stops a ray; a fence | Room's active object collider edges → raycaster |
| Light source | A bulb's position, radius, color, intensity; also called an emitter in this note | Room lights or Player → lighting calculation |
| Ray | A probe sent from an origin in one direction; it extends beyond the point defining its direction | Raycaster → intersection calculation |
| Intersection | Where a ray meets a line segment; retain the closest intersection along each ray | Intersection calculation → sight polygon |
| Sight polygon / visibility polygon | Ordered intersection points enclosing everywhere the source can reach; a stencil | Raycaster → lighting renderer |
| Lightmap | A sheet of illumination combined with the scene | Lighting renderer → scene compositor |

Suggested homes and dependency direction:

- **Geometry:** Room exposes active collider edges for lighting. [SpriteGeometry](../../mygame/app/sprite_geometry.rb) continues transforming generated artwork outlines for fading and diagnostics under [ADR-0012](../adr/0012-continuous-occluder-queries.md). No asset-generation changes are needed.
- **Inputs:** Room selects blockers and exposes enabled authored emitters. Player produces its lamp data. RoomPreview combines these into plain frame fields `light_sources` and `light_blockers`; Render continues to consume frame data without reaching into Room or Player.
- **Math:** add `mygame/app/raycasting.rb` for stateless intersection and visibility-polygon calculations. It consumes ordinary geometry, without DragonRuby outputs, input, or camera state.
- **Drawing:** add `mygame/app/lighting.rb` for polygon drawing, radial falloff, and lightmap preparation. Render calls it when composing the world scene. Keep the raycaster independent of drawing.
- **Tests:** add deterministic math coverage under `mygame/tests/raycasting_test.rb`, then lighting integration coverage under `mygame/tests/lighting_test.rb` and relevant existing suites.

Keep geometry in world coordinates until drawing. Reuse the installed SDK and existing occluder data; add no gems or runtime libraries. Consult `$DRAGONRUBY_HOME/docs/api/outputs.md` and `samples/07_advanced_rendering/14_triangles` when reaching the drawing checkpoint, and verify the needed operations in the installed Standard build.

### Keep the reference vocabulary

Use Ruby spelling while preserving the reference's concepts:

| Reference | Ruby adaptation | Meaning |
| --- | --- | --- |
| `getIntersection(ray, segment)` | `get_intersection(ray:, segment:)` | One ray/segment intersection, or `nil`; keyword arguments are the chosen Ruby interface |
| `getSightPolygon(sightX, sightY)` | `get_sight_polygon(sight_x, sight_y, segments:)` | Ordered intersections for a source; supply segments explicitly instead of reading a global |
| `ray.a`, `ray.b` | `ray[:a]`, `ray[:b]` | Origin and a second point defining its direction; `b` does not limit the ray's length |
| `segment.a`, `segment.b` | `segment[:a]`, `segment[:b]` | The finite segment's endpoints |
| `r_px`, `r_py`, `r_dx`, `r_dy` | Same names | Ray position and direction components, with direction calculated as `b - a` |
| `s_px`, `s_py`, `s_dx`, `s_dy` | Same names | Segment position and direction components |
| `T1`, `T2` | `t1`, `t2` | Parameters along the ray and segment; uppercase names would be Ruby constants |
| `param` | `:t` | The chosen return key for ray parameter `t1`; it is a distance only when the ray direction has unit length |

Both ray and segment use `{ a: { x: ..., y: ... }, b: { x: ..., y: ... } }`. Keep the existing renderer-friendly edge shape `{ x:, y:, x2:, y2: }` at the Room/debug boundary; convert it to endpoints when preparing segments for the raycaster. An intersection is `{ x: ..., y: ..., t: ... }` in the user's chosen naming.

This replaces the earlier conversational suggestion `intersection(origin:, direction:, segment:)`. Keep the reference's `ray` and its endpoints together rather than introducing a second public ray representation.

## Implementation ladder

Each step is a potential commit. Stop at its checkpoint before adding the next piece.

### 1. Connect the inputs

Expose enabled room emitters and active object colliders through the frame interface; append the player's circular emitter controlled by `lamp_on`. Carry owner identity so each emitter can omit its own object or mounted host. Actors receive light but do not cast shadows in this version. Keep offscreen blockers available: visibility is source-relative, not camera-relative.

Current Room records are `{ owner_ids: [...], sprite: ..., bounds: ..., edges: [...] }`, with edges shaped as `{ x:, y:, x2:, y2: }` in world coordinates. Source `ignore_owner_ids` determines exclusions. Caps and colliderless objects add no blockers. `light_receivers` identifies the separate receiving artwork and bases.

**Checkpoint (wired):** source markers agree with enabled lights; yellow collider borders locate physical blockers. Magenta outlines intentionally show the artwork used by fading, rather than lighting. Door changes update active blocking bases; flame animation and fading do not change them.

### 2. Intersect one ray with one segment

Start with `get_intersection(ray:, segment:)` and its tests, using the endpoint shapes above. Think of finding where a laser pointer meets a fence. Following the supplied snippet, accept `t1 >= 0` and `0 <= t2 <= 1`, including endpoints; return `t: t1` so you can compare intersections along the same ray. The guide's prose uses strict inequalities, but its endpoint-directed approach and the supplied snippet need endpoint intersections.

Adapt the math rather than copying the reference's division by `r_dx`: vertical rays make that unsafe. Its normalized-direction parallel check also misses opposite-direction parallel segments. Define a small numerical tolerance; return no hit for parallel/collinear pairs and degenerate rays or segments in this first version.

**Checkpoint:** tests cover vertical/horizontal rays, diagonal hits, opposite-direction parallel segments, segment endpoints, behind-origin intersections, misses, near-parallel cases, and zero-length inputs. Inputs remain unchanged.

### 3. Construct one visibility polygon

Follow the reference's sequence: collect unique endpoints, probe toward each endpoint and just beside it, retain each ray's nearest hit, then order the hits around the emitter. Begin with its angular offset of `0.00001` radians. Terminate unobstructed rays on a closed boundary around the emitter. The first prototype used a square; `Lighting` now supplies a 32-sided polygon inscribed in the radius circle. The raycaster itself remains independent of the chosen range boundary.

Draw a debug outline first. Think of walking around the bulb and recording the first fence visible in each direction. Handle an empty/degenerate result without trying to draw a polygon.

**Checkpoint:** tests and outlines show nearest-hit selection, corner shadow boundaries, disconnected blockers, concave shapes, duplicate endpoints, and an unobstructed bounded region. Move the origin near edges and corners to look for instability.

Historical outline prototype (2026-10-18; superseded by the integrated handoff above): `Raycasting.get_sight_polygon` feeds a red closed lamp outline through `RoomPreview#add_lamp_sight_polygon`. The helper converts blockers overlapping the lamp square into endpoint segments, adds four square border segments, and connects consecutive returned intersections back to the first. Only the magenta blocker overlay is viewport-culled. The lamp outline disappears when the lamp is off. Native preview regressions verify closure, movement, camera-independent world geometry, and preservation of the other debug overlays. Geometry regressions compare sampled polygon distances with the readable reference intersection method, including fractional origins, concave/disconnected outlines, negative-angle wraparound, source-on-segment cases, and short axis-aligned directions. Broader lighting integration coverage and manual shadow-edge playtesting are still needed before calling the lighting test suite complete.

#### Performance checkpoint before filling the light

The first all-room implementation tested 387 segments against 774 rays: 299,538 intersection attempts per source per frame. On the local Linux DragonRuby 7.21 Standard installation, its Ruby preview preparation took roughly 630–678 ms in three fixed positions. The user reported about 10 FPS in the smaller window and 4 FPS maximized. HD-off with optimizations restored 60 FPS in their playtest, but reverting every optimization returned sub-10 FPS. [ADR-0013](../adr/0013-keep-hd-disabled.md) makes HD-off mandatory; it does not remove the need to bound raycasting work.

The earlier bucket version retained three changes: selecting sprites intersecting the lamp square, preparing segment numbers once per calculation, and using 64 temporary direction buckets to select candidate segments. Buckets do **not** quantize or reduce the endpoint-directed rays; candidates still pass the same intersection inequalities. The numeric loop allocates only the nearest intersection for each ray. At this historical checkpoint there was no persistent cache, invalidation protocol, segment-clipping API, or extra runtime dependency. The integrated pass now reuses unchanged fixed-room results as described above. `get_intersection` stays readable as the reference/test oracle; the hot loop uses the equivalent determinant formulas.

The opt-in `bin/rake test tests/raycasting_benchmark.rb HEADLESS=1` measures five samples of three calls after warm-up and GC per sample. Historical bucket-version HD-off medians below include all Ruby preview preparation/submission, not engine drawing:

| Player position | Local segments including border | Polygon alone (ms) | Debug preview preparation (ms) |
| --- | --- | --- | --- |
| (176, 176) | 76 | 4.087 | 11.671 |
| (176, 72) | 116 | 5.221 | 12.255 |
| (280, 220) | 129 | 7.199 | 13.945 |
| (248, 220) | 149 | 9.787 | 16.826 |

The separate opt-in `bin/rake run -- --eval tests/raycasting_playback.rb` renders a moving-lamp workload, warms up for 30 frames, measures 60 frames per setting, and exits. Local offscreen OpenGL/software-rendered results with HD off:

| Window | Debug | Loop FPS | Median Ruby preparation (ms) |
| --- | --- | --- | --- |
| 640×360 | Off | 62.66 | 2.611 |
| 640×360 | On | 62.66 | 10.627 |
| 1920×1080 | Off | 62.67 | 2.750 |
| 1920×1080 | On | 60.63 | 11.974 |

Range filtering and direction buckets with the original per-candidate hash method reached only about 44 FPS in that rendered probe; retaining the allocation reduction was necessary. Full clipping and the larger numeric record/angle-filter version were discarded to keep the implementation smaller. Timings vary between workloads and hosts; these short offscreen runs do not establish the user's displayed FPS or visual acceptance. The next gate is the user's resized-window/corner/door playtest. m5x7 size-8 text softness is recorded separately in ADR-0013; do not restore HD for text clarity.

Bucket-only comparison (2026-10-18): removed only the direction index, preserving HD-off, lamp-range filtering, the prepared numeric records, and final-hit allocation. Ran the same moving-lamp probe immediately before and after removal, with debugging on:

| Window | With buckets: FPS / median preparation | Without buckets: FPS / median preparation |
| --- | --- | --- |
| 640×360 | 63.58 / 11.322 ms | 31.20 / 30.454 ms |
| 1920×1080 | 62.62 / 11.868 ms | 33.19 / 28.925 ms |

The user's own no-bucket playtest dropped to about 40 FPS. Buckets were restored during research, then removed for the following explicitly requested bounds experiment. See [standard optimization options](raycasting-optimization-options.md) for sourced alternatives and their implementation tradeoffs.

Historical bounds-only trial: **per-sprite bounds instead of buckets** (now removed). `RoomPreview` keeps each blocker's endpoint segments in a separate `segment_groups` entry. The raycaster derives an axis-aligned bounding box (AABB) from that group's actual world-space endpoints, relative to the source. A standard [ray/box slab test](https://www.pbr-book.org/4ed/Shapes/Basic_Shape_Interface#BoundsIntersectionTests) rejects a whole group before its exact edge tests. The four square border segments are tested first; a group beyond the nearest hit can also be skipped. Rays parallel to an axis, source-on-boundary cases and corner tangencies are handled inclusively. A tiny bounds expansion guards rounding at corners. Geometry and bounds rebuild each call; no cache, grid, sweep or runtime dependency was added.

During that trial, the flat `segments:` interface remained available alongside optional `segment_groups:`, an array of segment arrays with the same `{ a:, b: }` shapes. All endpoints still contribute the original three rays; this filter changes candidate work, not the polygon sampling. Keep lamp-square filtering and prepared numeric intersections. That trial’s native benchmark included `polygon_grouped`, alongside the identical geometry flattened into `polygon_local` (the grouped interface and benchmark operation have since been removed):

| Player position | Prepared flat polygon (ms) | Sprite-bounds polygon (ms) |
| --- | --- | --- |
| (176, 176) | 8.498 | 3.892 |
| (176, 72) | 14.614 | 6.647 |
| (280, 220) | 19.142 | 7.431 |
| (248, 220) | 24.235 | 10.140 |

Same native moving-lamp probe, HD off, with bounds instead of buckets:

| Window | Debug | Loop FPS | Median Ruby preparation (ms) |
| --- | --- | --- | --- |
| 640×360 | Off | 62.69 | 2.894 |
| 640×360 | On | 60.51 | 14.745 |
| 1920×1080 | Off | 63.88 | 2.849 |
| 1920×1080 | On | 56.74 | 16.494 |

This is substantially faster than the flat loop, with less margin than buckets in the moving-lamp workload. The bounds-only version was left active for the user's playtest before the angular-span trial below. At that checkpoint, all 169 native tests passed, including grouped-versus-flat polygon equivalence for concave/disconnected outlines, fractional origins, border-crossing segments, zero-width/degenerate groups, source-on-edge cases, and direct slab tests for axis-parallel rays, tangencies and nearest-hit rejection. These checks do not establish visual acceptance or FPS on the user's machine.

Historical follow-up: **sprite bounds plus per-edge angular spans**, with buckets still removed (also now removed). Each prepared edge now stores the center angle and half-width of its shorter angular arc. After the sprite box passes, compare the ray angle against that span before running the existing determinant math. Circular angle distance handles the -π/π boundary. Edges touching/crossing the source use a full-circle span so hits at `t=0` remain possible; tiny angular padding retains endpoint rays. Every candidate edge still receives a span check, so this borrows the buckets' angular rejection without their direct candidate lookup. There is no rotational sweep or persistent index, and the public interface is unchanged.

Fresh before/after native measurements (same benchmark, HD off) show mixed fixed-position results; the added span preparation and checks do not always pay for themselves after sprite bounds have already removed most candidates:

| Player position | Bounds only: polygon (ms) | Bounds + edge spans: polygon (ms) |
| --- | --- | --- |
| (176, 176) | 3.820 | 4.165 |
| (176, 72) | 7.054 | 6.552 |
| (280, 220) | 7.398 | 7.524 |
| (248, 220) | 10.430 | 9.682 |

The flat local loop without sprite bounds improved from 8.529–24.974 ms to 6.727–18.616 ms across those positions. Those are separate flat-call results, not the runtime's grouped path. Moving-lamp playback with the B overlay on showed a modest benefit:

| Window | Bounds only: FPS / median preparation | Bounds + edge spans: FPS / median preparation |
| --- | --- | --- |
| 640×360 | 52.17 / 17.510 ms | 57.42 / 15.303 ms |
| 1920×1080 | 55.77 / 16.909 ms | 57.95 / 15.876 ms |

Overlay-off playback stayed near 62 FPS in both versions. Earlier bounds-only runs reached higher FPS than this control, so do not infer a universal gain from one short moving-lamp comparison. That version was left active for playtesting before the return to buckets below; it did not recover their full advantage. All 169 native tests and RuboCop passed at that checkpoint. New regressions compare every generated ray against the readable reference using the same source-relative unit directions, including angle wrap, thin triangles, reversed edges, fractional origins, and source contacts. Exactly tangent rays are sensitive to floating-point rounding; matching the reference's direction arithmetic avoids comparing slightly different rays.

Current implementation: **restore the 64 direction buckets; keep only complementary work**. Lamp-square filtering remains before bucket construction because it reduces both input segments and endpoint rays. Prepared numeric records and allocating only final hits remain because they reduce intersection cost independently of candidate selection. HD remains disabled. Per-ray sprite AABB checks, per-edge exact angular-span checks, and the optional `segment_groups:` interface are removed. RoomPreview supplies a flat `segments:` array again.

Before deciding, a temporary native comparison tested buckets alone, buckets + edge spans, buckets + sprite bounds, and all three. All variants used the same endpoint rays, range-selected geometry, numeric intersection math and 64 buckets. Span preparation reused the endpoint angles already computed for buckets. Bounds results were cached once per sprite per ray, with the nearest hit available for rejection, rather than testing the box again for each edge. Group bounds and bucket preparation were included in the measured calls. Each variant warmed up; nine samples of five calls used rotated/reversed execution order and GC before each sample. Every returned angle and distance was compared with plain buckets at each position. Median polygon times:

| Player position | Buckets (ms) | + edge spans (ms) | + sprite bounds (ms) | + both (ms) |
| --- | --- | --- | --- | --- |
| (176, 176) | 3.431 | 3.419 | 3.919 | 3.929 |
| (176, 72) | 3.785 | 3.943 | 4.772 | 4.675 |
| (280, 220) | 4.908 | 4.854 | 4.922 | 5.098 |
| (248, 220) | 5.936 | 6.065 | 6.104 | 6.567 |

The edge-span differences ranged from roughly 1% faster to 4% slower, offering no clear complementary gain. Sprite bounds were slower at every position; some differences were small, with the largest about 26%. Keeping both was also slower. The temporary variant implementations were removed after recording the result; no experimental mode flags or duplicate raycasters remain. These results establish this workload's tradeoff, not that those techniques are generally obsolete.

Fresh moving-lamp playback immediately before/after restoration, with the overlay on and HD off:

| Window | Bounds + spans: FPS / median preparation | Restored buckets: FPS / median preparation |
| --- | --- | --- |
| 640×360 | 53.61 / 16.768 ms | 62.43 / 12.029 ms |
| 1920×1080 | 53.67 / 16.791 ms | 59.47 / 12.724 ms |

Overlay-off playback remained about 62 FPS. The restored runtime also passed the regular native benchmark; full-room polygon medians were 16.807–21.181 ms versus local-range medians of 3.594, 3.621, 8.619 and 6.184 ms at the four positions. One position had substantial timing variance, so use the interleaved comparison above to assess the extra filters. Native checks now pass all 168 tests and RuboCop: the private AABB-only test was retired with that helper, while crossing-edge, degenerate-edge, source-contact, reversed-edge, wraparound, fractional-origin and reference-hit regressions remain. Visual acceptance and displayed FPS still require the user's playtest.

### 4. Draw one bounded light

This ladder records the implementation order following the [many-light audit](many-light-raycasting-audit.md). Steps 4.1, 4.2, 5.1, 5.2, and 5.3 are wired into RoomPreview; final tuning and playtesting remain. Keep existing buckets and `hd=false`. Measurements of the integrated pass justified fixed-room polygon reuse; a grid remains deferred.

**4.1. Give the polygon a consumer outside diagnostics (complete).** `RoomPreview` combines room and player lighting inputs, then calls `Lighting.prepare`. `frame[:light_polygons]` carries source and world-space polygon together. Rendering and red-line diagnostics consume the same result. `Raycasting` remains responsible for geometry without output/camera dependencies.

Checkpoint: B changes diagnostic visibility without another solve. Toggling a lamp removes its contribution.

**4.2. Fill the sight polygon with a triangle fan (complete).** A triangle fan is a pizza cut from its center: source, boundary point, next boundary point. Include the last-to-first boundary pair. This works for the source-visible polygon even when its outline is concave. Have the drawing side of `Lighting` turn those triples into DragonRuby triangles. Render them temporarily in a conspicuous flat color over the scene so geometry errors are easy to inspect. Skip polygons with fewer than three boundary points.

Use the same `camera.for_drawing` snapshot as `Render.draw`. Apply `Camera#to_screen` separately to the source and every triangle vertex; transforming a whole triangle hash would only change `x`/`y`, leaving `x2`/`y2` and `x3`/`y3` untouched. Preserve fractional coordinates through this conversion. Keep the red boundary available for comparison.

Checkpoint: the fill meets the outline, closes completely, follows the lamp, and remains attached to scenery while the camera scrolls. The current border is a 32-sided circle approximation; mask falloff softens its hard outer edge.

### 5. Composite the full scene

**5.1. Build a lightmap and apply it (complete, floor only).** A render target is an offscreen canvas. A lightmap is a canvas whose RGB values say how much scene color survives: white preserves it, black removes it, gray dims it. Let `Lighting` prepare a viewport-sized `:lightmap` target, matching the existing `:scene` dimensions. Start each frame with an opaque ambient-gray baseline: 12% brightness is approximately RGB 31, with alpha 255. Add the mask-textured polygon as illumination.

Prepare the lightmap before `Render.draw` creates its scene target. Draw floor sprites directly into the scene, multiply the lightmap over them, then append the separately tinted foreground in its existing depth/fade order. This preserves floor-only illumination without another floor render target. The installed 7.21 triangle path uses **`blendmode_enum: 2` for additive** contributions; ordinary target sprites use **`blendmode: 8` for multiply** composition. Sample one target into another, never into itself. Draw diagnostics and the HUD afterward.

Checkpoint: the hard-edged visible region preserves normal scene color, blocked areas receive ambient brightness, lamp-off leaves ambient alone, diagnostics/HUD retain their colors, and movement leaves no trails. Rebuild the lightmap each frame, including frames with no lights.

**5.2. Paint radial falloff through the polygon (complete).** The flat fill is replaced by triangle sampling of the supplied mask profile. Think of the sight polygon as a stencil and the texture as paint fading from its center. Source texture coordinates follow each vertex's offset within the light's `2 * radius` square. The texture contributes most at its center and zero at the circular radius; geometry still gives sharp shadow edges.

The existing `mygame/sprites/light_mask.png` stores its falloff in alpha. `Lighting.draw_light_mask` prepares the white illumination texture at `:radial_light` before `:lightmap` consumes it. `Lighting.triangles` maps that texture through each source polygon; `Raycasting` needs no change. See the mask notes above for the conversion blend and target order.

Checkpoint: the light fades to ambient at its configured radius, its polygonal outer edge is softened, shadows remain sharp, and texture placement remains aligned during movement.

**5.3. Feed the same pass every enabled source (complete).** Preparation consumes all frame `light_sources`. Positive authored radii override the room fallback of 48; the player uses 64. Empty color uses white, and intensity scales the contribution. For each source, omit owner groups matching its exclusions and retain the circular range boundary. Physical colliders of other light objects remain blockers.

Accumulate contributions additively into one ambient lightmap and multiply the floor once. Foreground artwork receives separate base samples. If later selecting sources for the camera, use influence-bounds overlap and retain relevant offscreen blockers.

Checkpoint: room lights overlap, toggle, and respect door states; flames and fading do not change physical blockers. Cache tests cover door/source changes and reloads. Measure the integrated room with diagnostics off before adding another optimization. The earlier [audit](many-light-raycasting-audit.md) used different geometry and radii; its raw timings are historical controls.

SDK reading at the relevant checkpoint: `$DRAGONRUBY_HOME/docs/api/outputs.md` sections **Triangles** and **Blending**; `samples/07_advanced_rendering/14_triangles` for triangle primitives. The `13_lighting` sample demonstrates render-target wiring but uses a different composition technique, so do not copy its blending recipe as this plan's lightmap equation. No gems or runtime libraries are needed.

### 6. Complete regression coverage and playtest

Cover moving lamp origins, enabled states, door variants, light animation, per-emitter owner exclusions, offscreen lights/blockers, reload, and frames with no lights. Keep numerical geometry tests independent of the SDK's renderer; integration checks should establish frame data and rendering behavior without pretending to prove visual quality.

Run narrow native tests while iterating, then `bin/rake test` and `bin/rubocop` for the completed PR. Use the [DragonRuby testing reference](../../.agents/skills/dragonruby-development/references/testing.md) for project commands.

**Checkpoint:** automated checks pass. Manually inspect mounted flames, corner leaks, door transitions, lamp toggles, overlapping colors, darkness readability, and camera motion. Measure the completed room before considering further caching or spatial indexing. Record automated results separately from playtest observations.

## Initial defaults and boundaries

- Use sharp shadow edges and soft radial falloff; the lamp emits in all directions.
- Use player radius 64 world pixels, room fallback radius 48, intensity 1, white light, and ambient brightness 12%. Positive authored radii and authored colors override these defaults; zero radius and empty color use defaults. Intensity controls each light's contribution.
- Place the player emitter at its foot-collider center on the ground plane, so a southern wall cannot coincide with the ray origin. Room sources keep authored X and use their collider base's lowest Y; mounted sources use one world pixel south/in front of the host baseline to avoid a blocking wall edge.
- Exclude the emitter's own collider owner and mounted host group only for that emitter. Other objects' colliders still block it; inspect mounted wall illumination during playtesting.
- Blockers use active object colliders regardless of temporary foreground fade opacity. Generated alpha geometry remains specific to fading and diagnostics. Height-aware shadows are deferred.
- Witness detection, actor shadows, soft shadow edges, flicker, and speculative performance infrastructure are outside this PR.
- Radius, lamp anchor, and ambient brightness are tuning defaults. Final visual acceptance requires playtesting; implementation details can be learned at each checkpoint without supplying the solution here.

## Reference snippet

User-supplied reference, preserved unchanged. Related explanation: Nicky Case's [Sight & Light](https://ncase.me/sight-and-light/). This is the supplied variant, not a verbatim copy of the guide's demos.

```html
<!doctype html>
<html>
	<head>
		<meta charset="utf-8">
		<title>2D Raycasting Sight Polygon Preview (Sharp Edges)</title>
		<style>
		body {
			margin: 0;
			background: #222;
			display: flex;
			justify-content: center;
			align-items: center;
			height: 100vh;
		}
		#canvas {
			width: 840px;
			height: 360px;
			background: #333;
			box-shadow: 0 10px 30px rgba(0,0,0,0.5);
			cursor: crosshair;
		}
		</style>
	</head>
	<body>
		<canvas id="canvas" width="840" height="360"></canvas>
	</body>
</html>
<script>

// Find intersection of RAY & SEGMENT
function getIntersection(ray, segment){
	var r_px = ray.a.x;
	var r_py = ray.a.y;
	var r_dx = ray.b.x - ray.a.x;
	var r_dy = ray.b.y - ray.a.y;

	var s_px = segment.a.x;
	var s_py = segment.a.y;
	var s_dx = segment.b.x - segment.a.x;
	var s_dy = segment.b.y - segment.a.y;

	var r_mag = Math.sqrt(r_dx * r_dx + r_dy * r_dy);
	var s_mag = Math.sqrt(s_dx * s_dx + s_dy * s_dy);
	if (r_dx / r_mag == s_dx / s_mag && r_dy / r_mag == s_dy / s_mag) {
		return null;
	}

	var T2 = (r_dx * (s_py - r_py) + r_dy * (r_px - s_px)) / (s_dx * r_dy - s_dy * r_dx);
	var T1 = (s_px + s_dx * T2 - r_px) / r_dx;

	if (T1 < 0) return null;
	if (T2 < 0 || T2 > 1) return null;

	return {
		x: r_px + r_dx * T1,
		y: r_py + r_dy * T1,
		param: T1
	};
}

function getSightPolygon(sightX, sightY){
	var points = (function(segments){
		var a = [];
		segments.forEach(function(seg){
			a.push(seg.a, seg.b);
		});
		return a;
	})(segments);
	
	var uniquePoints = (function(points){
		var set = {};
		return points.filter(function(p){
			var key = p.x + "," + p.y;
			if (key in set) {
				return false;
			} else {
				set[key] = true;
				return true;
			}
		});
	})(points);

	var uniqueAngles = [];
	for (var j = 0; j < uniquePoints.length; j++) {
		var uniquePoint = uniquePoints[j];
		var angle = Math.atan2(uniquePoint.y - sightY, uniquePoint.x - sightX);
		uniquePoint.angle = angle;
		uniqueAngles.push(angle - 0.00001, angle, angle + 0.00001);
	}

	var intersects = [];
	for (var j = 0; j < uniqueAngles.length; j++) {
		var angle = uniqueAngles[j];
		var dx = Math.cos(angle);
		var dy = Math.sin(angle);

		var ray = {
			a: {x: sightX, y: sightY},
			b: {x: sightX + dx, y: sightY + dy}
		};

		var closestIntersect = null;
		for (var i = 0; i < segments.length; i++) {
			var intersect = getIntersection(ray, segments[i]);
			if (!intersect) continue;
			if (!closestIntersect || intersect.param < closestIntersect.param) {
				closestIntersect = intersect;
			}
		}

		if (!closestIntersect) continue;
		closestIntersect.angle = angle;
		intersects.push(closestIntersect);
	}

	intersects = intersects.sort(function(a, b){
		return a.angle - b.angle;
	});

	return intersects;
}

///////////////////////////////////////////////////////

// DRAWING
var canvas = document.getElementById("canvas");
var ctx = canvas.getContext("2d");

function draw(){
	// Clear canvas
	ctx.clearRect(0, 0, canvas.width, canvas.height);

	// Draw obstacles/walls
	ctx.strokeStyle = "#888";
	ctx.lineWidth = 2;
	segments.slice(4).forEach(function(seg){
		ctx.beginPath();
		ctx.moveTo(seg.a.x, seg.a.y);
		ctx.lineTo(seg.b.x, seg.b.y);
		ctx.stroke();
	});

	// Get single sharp sight polygon
	var polygon = getSightPolygon(Mouse.x, Mouse.y);

	// DRAW SHARP LIGHT CONE
	drawPolygon(polygon, ctx, "rgba(255,255,255,0.7)");

	// Draw center mouse dot
	ctx.fillStyle = "#ffcc00";
	ctx.beginPath();
	ctx.arc(Mouse.x, Mouse.y, 3, 0, 2 * Math.PI, false);
	ctx.fill();
}

function drawPolygon(polygon, ctx, fillStyle){
	ctx.fillStyle = fillStyle;
	ctx.beginPath();
	ctx.moveTo(polygon[0].x, polygon[0].y);
	for (var i = 1; i < polygon.length; i++) {
		var intersect = polygon[i];
		ctx.lineTo(intersect.x, intersect.y);
	}
	ctx.fill();
}

// LINE SEGMENTS
var segments = [
	// Border
	{a: {x: 0, y: 0}, b: {x: 840, y: 0}},
	{a: {x: 840, y: 0}, b: {x: 840, y: 360}},
	{a: {x: 840, y: 360}, b: {x: 0, y: 360}},
	{a: {x: 0, y: 360}, b: {x: 0, y: 0}},

	// Polygon #1
	{a: {x: 100, y: 150}, b: {x: 120, y: 50}},
	{a: {x: 120, y: 50}, b: {x: 200, y: 80}},
	{a: {x: 200, y: 80}, b: {x: 140, y: 210}},
	{a: {x: 140, y: 210}, b: {x: 100, y: 150}},

	// Polygon #2
	{a: {x: 100, y: 200}, b: {x: 120, y: 250}},
	{a: {x: 120, y: 250}, b: {x: 60, y: 300}},
	{a: {x: 60, y: 300}, b: {x: 100, y: 200}},

	// Polygon #3
	{a: {x: 200, y: 260}, b: {x: 220, y: 150}},
	{a: {x: 220, y: 150}, b: {x: 300, y: 200}},
	{a: {x: 300, y: 200}, b: {x: 350, y: 320}},
	{a: {x: 350, y: 320}, b: {x: 200, y: 260}},

	// Polygon #4
	{a: {x: 540, y: 60}, b: {x: 560, y: 40}},
	{a: {x: 560, y: 40}, b: {x: 570, y: 70}},
	{a: {x: 570, y: 70}, b: {x: 540, y: 60}},

	// Polygon #5
	{a: {x: 650, y: 190}, b: {x: 760, y: 170}},
	{a: {x: 760, y: 170}, b: {x: 740, y: 270}},
	{a: {x: 740, y: 270}, b: {x: 630, y: 290}},
	{a: {x: 630, y: 290}, b: {x: 650, y: 190}},

	// Polygon #6
	{a: {x: 600, y: 95}, b: {x: 780, y: 50}},
	{a: {x: 780, y: 50}, b: {x: 680, y: 150}},
	{a: {x: 680, y: 150}, b: {x: 600, y: 95}}
];

// DRAW LOOP
window.requestAnimationFrame = window.requestAnimationFrame || window.webkitRequestAnimationFrame || window.mozRequestAnimationFrame || window.msRequestAnimationFrame;
var updateCanvas = true;

function drawLoop(){
	requestAnimationFrame(drawLoop);
	if (updateCanvas) {
		draw();
		updateCanvas = false;
	}
}

window.onload = function(){
	drawLoop();
};

// MOUSE
var Mouse = {
	x: canvas.width / 2,
	y: canvas.height / 2
};

canvas.onmousemove = function(event){
	Mouse.x = event.offsetX;
	Mouse.y = event.offsetY;
	updateCanvas = true;
};
</script>
```
