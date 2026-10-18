# Lighting conventions audit

Date: 2026-10-19. Research against the current implementation; no design change is proposed.

Subsequent simplification: [ADR-0015](../adr/0015-use-colliders-for-foreground-fading.md) removes the alpha/polygon pipeline and adopts active colliders for fading too. The temporary full-artwork comparison below used the former generated geometry and remains historical; the lighting/receiving findings are unchanged.

## Finding

The raycaster follows a familiar 2D visibility-polygon method. Most adaptations for tall foreground artwork sit in the choice of light blockers and in how foreground sprites receive light. A percentage would be misleading: geometry, numerical handling, performance work, and artistic policy serve different purposes. The accepted model remains [ADR-0014](../adr/0014-use-collider-bases-for-lighting.md); terms follow [GLOSSARY.md](../../GLOSSARY.md#rendering).

The important distinction is height implied by artwork. A large, flat floor sprite can cover several tiles without this problem. An upright wall sprite projects its height over floor coordinates behind its base. Treating its complete drawn outline as a floor obstacle, or applying the floor lightmap directly to it, confuses those two meanings of position. This is the reason for the project's ground-base model. [Decision and rationale](../adr/0014-use-collider-bases-for-lighting.md), [current Room inputs](../../mygame/app/room.rb)

## Conventional geometry and rendering work

| Current mechanism | Comparison and purpose |
| --- | --- |
| Cast at each segment endpoint and at its angle ±0.00001; keep nearest hits; sort by angle | This directly follows Nicky Case's method. The offset rays catch surfaces just past a corner. It works with ordinary flat obstacles. [Raycasting](../../mygame/app/raycasting.rb), [Sight & Light](https://ncase.me/sight-and-light/) |
| Determinant tests, source-contact handling, angle wrap, endpoint precision | General geometric boundary conditions. Red Blob's author also documents numerical robustness problems in a visibility implementation. These conditions occur with flat obstacles. [Raycasting](../../mygame/app/raycasting.rb), [Red Blob implementation discussion](https://www.redblobgames.com/articles/visibility/#implementation) |
| Nearby-blocker selection, 64 angle buckets, prepared numeric records, fixed-light polygon caching | Performance choices that preserve the intended geometric result; the exact implementation is local. Door/source changes invalidate the cache. [Lighting](../../mygame/app/lighting.rb), [RoomPreview](../../mygame/app/room_preview.rb) |
| Circle-bounded polygons, triangle fills, radial mask, ambient illumination and accumulated lights | Established visibility-lightmap techniques. Red Blob describes radius clipping, gradient circles, per-light visibility, and bitmap composition. Our 32-sided boundary and DragonRuby pass wiring are implementation choices. [Lighting](../../mygame/app/lighting.rb), [Red Blob](https://www.redblobgames.com/articles/visibility/) |

Separating shadow-casting shapes from light-receiving artwork is also an established capability. Godot has distinct occluder nodes, sprite receivers, and per-light casting/receiving masks. Our particular ground-base and tint policy is the adaptation. [Godot official documentation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)

## Policies chosen for this game's foreground artwork

| Policy | Reason and visible compromise |
| --- | --- |
| Active movement colliders become ground-plane light blockers | Tall artwork and ceiling caps add no floor obstacle. Door blockers follow their active collision state. This reuses authored ground occupancy, so collision accuracy also limits shadow accuracy. [Room#light_blockers](../../mygame/app/room.rb) |
| Apply the spatial lightmap to the floor; tint foreground sprites separately | Each sprite receives one RGB multiplier derived from its base. Tall artwork avoids having unrelated floor shadows painted across it, but has no illumination gradient or partial shadow across its own surface. [Render](../../mygame/app/render.rb), [Lighting.receiver_colors](../../mygame/app/lighting.rb) |
| Sample the nearest point on each rectangular base; use the maximum strength across multipart bases | Cheap object-level lighting. One exposed part can brighten the whole sprite. Conversely, a blocked nearest point can leave a sprite dark even if a farther part of that same base is exposed. These are deductions from the sampling rule. [received_light_strength and receiver_colors](../../mygame/app/lighting.rb) |
| Reject sources behind a south-facing face through `front_y` | Prevents a visible side/corner from brightening the entire face from behind. Face recognition uses the current wall/door collider layout: full-width, thin, and at the artwork's lower edge. Top-down strips and side walls keep ordinary sampling. This is the most explicit artwork-specific corner rule. [Room#south_facing_face?](../../mygame/app/room.rb), [Lighting.receiver_colors](../../mygame/app/lighting.rb) |
| Leave caps at ambient; use placement baselines for colliderless receivers | Keeps ceiling artwork simple and lets decoration receive light without inventing a blocker. These are artistic policies. [Room#lighting_bases](../../mygame/app/room.rb), [Render](../../mygame/app/render.rb) |
| Project room sources to their ground bases; share mounted host ownership and move mounted sources one pixel south | Adapts elevated flames to a ground-plane solver. The one-pixel clearance avoids collapsed polygons on overlapping wall edges. Exclusion masks are conventional; these host rules and offset are local. [Room#light_sources](../../mygame/app/room.rb), [mounted-light regressions](../../mygame/tests/room_test.rb) |

## Three different corner issues

1. **Rays passing a corner:** the ±0.00001 endpoint angles are part of the reference algorithm. [Sight & Light](https://ncase.me/sight-and-light/)
2. **A receiver flickering at a polygon vertex:** `visible?` selects the angular boundary edge and tests its inward side with a cross product and tolerance. This avoids a second strict endpoint intersection. The 0.01-pixel receiving offset samples just toward the light so the near blocking surface can receive light. Both are numerical boundary treatments; base sampling makes them relevant here. [Lighting](../../mygame/app/lighting.rb), [movement regression](../../mygame/tests/lighting_test.rb)
3. **An exposed corner lighting a face from behind:** `front_y` imposes a south-facing surface rule. This compensates for assigning one value to the whole sprite. [Backlighting regression](../../mygame/tests/room_test.rb)

Centering the Player's source inside the foot collider is another origin-placement fix: southern contact must not place the emitter on a wall edge. [Player](../../mygame/app/player.rb), [contact regression](../../mygame/tests/room_preview_test.rb)

## Limits of the comparison

There is no single conventional 2D lighting implementation. The sources establish comparable techniques and capabilities, rather than identical engines. Godot also supports per-pixel normal-map responses; its documented virtual light height has restricted effects. Adding normal maps alone would not replace this game's missing world-height shadow model. [Godot normal-map and height documentation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)

The current model has no finite object heights, partial face shadows, or actor shadow casting. Floor falloff uses the supplied mask; foreground strength uses linear distance, so their brightness profiles can differ. These are accepted approximations, independent of polygon correctness. This audit inspected code and regression coverage; it did not run new performance measurements or visual acceptance tests. [ADR-0014](../adr/0014-use-collider-bases-for-lighting.md), [implementation guide](raycast-lighting.md)

## Uniform tinting is a general approximation

Calling whole-sprite tinting itself project-specific was too broad. Applying one RGB multiplier to a sprite is an established rendering operation: Godot exposes per-item modulation and documents multiplication with texture color. It preserves the artwork's existing color and shading variation; the multiplier is uniform, rather than replacing every pixel with one flat color. Those properties provide the operation, not an automatic light-sampling policy. [Godot CanvasItem properties](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-self-modulate), [shader color semantics](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html#color-and-texture)

Using a coarse light estimate for a whole receiving surface is also a general approximation. The cited 2.5D experiment initially shades an entire wall receiver according to the light's position relative to the receiver's bottom edge, then adds spatially varying shadows. This is evidence of the broader approach outside this project, while its final lighting and sampling algorithm differ from ours. It does not establish a universal top-down convention. [Developer explanation](https://github.com/basementuniverse/lighting-2d#how-it-works)

The project-specific part is the exact combination: nearest point on each collider base, prepared-polygon visibility, linear falloff, maximum contribution across multipart bases, and the inferred south-facing `front_y` restriction. Uniform modulation is the means of displaying that estimate. Low-detail receiving and the missing height model remain separate choices. [Current receiver calculation and tint](../../mygame/app/lighting.rb)

This choice reduces the number of receiver queries in our Ruby implementation. For each light/receiver pair, it checks the applicable bases instead of repeating visibility for many face samples. Applying the resulting tint still involves rendering the sprite's pixels. More samples using the same Ruby path would add CPU work; this establishes neither a measured frame-rate benefit nor that per-pixel lighting is inherently slower. A GPU shader or receiver lightmap organizes work differently. Godot, for example, performs its light processing during the regular draw pass. A valid performance comparison must identify the actual alternatives and measure total frame cost, including CPU preparation, drawing, and extra passes. [Current loops](../../mygame/app/lighting.rb), [Godot light-processing reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html#light-built-ins)

## Conventional counterparts of the five receiving rules

Visibility and distance attenuation are ordinary lighting ingredients. The tailored choices are where this implementation samples them and how it reduces several base samples to one sprite color. The comparison below describes established alternatives, without requiring every game to use the same model.

| Current ingredient | Conventional counterpart | What is tailored here? |
| --- | --- | --- |
| Nearest point on a collider base | Evaluate lighting at a chosen receiving surface point, vertex, or fragment. A physically richer renderer uses the actual surface position. | Using the nearest ground-base point as a proxy for the entire upright sprite. [PBRT surface-light evaluation](https://www.pbr-book.org/4ed/Light_Transport_I_Surface_Reflection/A_Simple_Path_Tracer) |
| Visibility of that point | A shadow ray tests the path between a receiver and a light; a shadow map instead compares the receiver's light-space depth with stored depths. Our prepared polygon supplies the equivalent flat-visibility question. | The base sample and particular polygon query, rather than checking visibility itself. [PBRT shadow ray](https://www.pbr-book.org/4ed/Light_Transport_I_Surface_Reflection/A_Simple_Path_Tracer), [Microsoft shadow-depth maps](https://learn.microsoft.com/en-us/windows/win32/dxtecharts/common-techniques-to-improve-shadow-depth-maps) |
| Linear distance falloff | Physical point lights use inverse-square attenuation; artistic 2D lights can use configurable radial textures or gradients. | The selected linear profile and its distance to the base proxy. Attenuation is conventional; inverse-square is optional for the intended style. [PBRT point lights](https://pbr-book.org/4ed/Light_Sources/Point_Lights), [Godot radial falloff](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html#point-lights) |
| Maximum strength across multipart bases | Spatially resolved receiving keeps each sample's own light value at its own position. Collapsing those values to one object color requires an additional approximation. | Choosing the brightest part to represent the entire sprite. A weighted average is another possible reduction, with different artifacts; it is not a universal standard. [Current maximum reduction](../../mygame/app/lighting.rb) |
| `front_y` rejects a light behind a south-facing face | A surface normal supplies its facing direction. An opaque, one-sided diffuse surface uses a factor such as `max(0, dot(normal, direction_to_light))`. | Inferring a south-facing normal from tile/collider layout and using a binary Y test. The underlying facing-light rule is conventional. [Godot's diffuse shader example](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html#light-built-ins) |

For a south-facing planar normal, the sign of that dot product reduces to whether the light is south of the surface. Our `front_y` therefore approximates a surface-facing test; cosine weighting would also change brightness with incidence angle. Such a vector calculation can be evaluated once per object in Ruby. It inherently requires neither per-pixel shading nor a 3D engine. Actual finite-height shadowing is the separate visibility extension discussed below.

The maximum above combines **parts of one receiver for one light**. Contributions from **different lights** already add in `receiver_colors`, consistent with additive illumination. [Current accumulation](../../mygame/app/lighting.rb), [PBRT direct-light accumulation](https://www.pbr-book.org/4ed/Light_Transport_I_Surface_Reflection/A_Simple_Path_Tracer)

These counterparts do not imply a performance ranking. Additional samples through the current CPU path add work; GPU surface shading or different lightmaps need their own measurements. Replacing a binary facing test with a dot product is a much smaller change than replacing object-level receiving or the visibility model.

## Adding height without discarding the floor plan

The ground plan remains useful in a height-aware model. A base describes the object's horizontal occupancy. Height describes how far that object extends above the floor. Using independently authored casting shapes is an established engine capability: Unity's Shadow Caster 2D accepts a sprite outline, a Collider 2D shape, or a manually edited shape. It separately controls self-shadowing, shadows on other objects, and receiving sorting layers. This establishes the flexibility of casting geometry; it does not establish that base-only blockers are an industry-wide top-down convention. [Unity component reference](https://docs.unity.com/en-us/engine/6000.3/manual/unity2d/2d-urp/2d-index/2d-shadows/shadow-caster2d)

Two independent limitations need separate decisions:

| Question | Current answer | Possible extension |
| --- | --- | --- |
| Where do we evaluate received light? | One strength per base, then one tint for the sprite | Several samples or a receiver lightmap, allowing different parts of a face to receive different amounts of light |
| What geometry blocks the path to each receiving point? | Flat visibility with every encountered blocker stopping the ray | Finite-height volumes, or suitable height/depth data, allowing light to pass above a short object |

Finer receiving can improve partial illumination while retaining flat shadow geometry. Adding finite blocker heights can improve visibility while retaining coarse receiver shading. A more complete model combines both. This distinction follows from the separate sampling and visibility steps in [Lighting](../../mygame/app/lighting.rb).

One possible extension is to extrude each ground base into a simple prism. Rectangular bases become boxes described by XY bounds and minimum/maximum Z. Give lights a world height and map each receiving sample to XYZ: floor samples have Z = 0, while face samples rise above the base. Then test the segment between the light and each sample against blocking volumes. Ray–box intersection and shadow-ray predicates are established geometry operations; applying them to our colliders would be a project design choice. [PBRT's ray–bounds and shadow-ray intersection reference](https://www.pbr-book.org/4ed/Shapes/Basic_Shape_Interface)

For example, a ray from an elevated lamp may clear a low coffin and reach the floor farther away, while a taller wall still stops it. The current polygon ends at the nearest XY obstruction. A scalar correction after that result cannot recover discarded farther blockers or represent all receiver heights. A height-aware version must change visibility queries or shadow projection, while retaining useful base data, source ownership, movement collision, and rendering order. This is a geometric consequence of the proposed prism model, rather than an implemented feature. [Current nearest-hit solver](../../mygame/app/raycasting.rb)

A less physical alternative also builds on floor geometry. The open-source `lighting-2d` experiment maintains ground and wall lightmaps, shades faces relative to their bottom edges, and projects ground shadows onto wall receivers. It demonstrates a richer receiving approximation without a general 3D volume solver; its two wall layers have overlap limits. [Developer implementation](https://github.com/basementuniverse/lighting-2d#how-it-works)

Normal maps provide surface directions for shading. They alone supply neither finite blocking volumes nor per-pixel world positions. Godot explicitly limits virtual light height to normal-map response and documents unchanged directional-shadow length. Height fields, camera-depth sprites, and normal maps encode different information and require matching visibility algorithms. [Godot documentation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)

A useful DragonRuby experiment would retain one floor plan and 2D artwork, add one short box, one tall wall, one elevated light, and a few explicit floor/face XYZ samples, then compare visibility while moving the lamp. This is a proposed feasibility test, not a performance prediction or an accepted implementation change. The project's existing sprite/triangle rendering would still present the result; producing receiver lightmaps across the room would be additional work. [Current drawing path](../../mygame/app/lighting.rb), [accepted scope](../adr/0014-use-collider-bases-for-lighting.md)

## Full artwork outlines or bounds: local comparison

2026-10-19. Using full projected artwork polygons or their occupied bounding rectangles as flat blockers would not supply world height. A wall's drawn height would occupy additional floor space in the lighting calculation. Changing blockers alone also leaves the current whole-sprite receiving tint in place. Applying a lightmap over the complete scene is a separate compositor change: it can vary illumination across sprite pixels, but still uses their projected XY positions as if all receiving pixels belonged to the same plane. This recreates the mismatch documented in [the foreground research](foreground-lighting-research.md).

The geometry-source change belongs in `Room#light_blockers`; source placement and owner exclusions would need review. The raycaster can retain its segment interface. Changing receiver shading requires separate changes in `Lighting.receiver_colors` and `Render.draw`. `RoomPreview.prepare_lighting` currently compares blocker owner IDs and bounds; outline-based blocking would also need to detect edge changes within unchanged bounds. Animated flame outlines can invalidate fixed-light results, whereas their movement colliders currently remain stable. [Room](../../mygame/app/room.rb), [Lighting](../../mygame/app/lighting.rb), [Render](../../mygame/app/render.rb), [cache](../../mygame/app/room_preview.rb)

A temporary native probe at `mygame/tmp/occluder_comparison_probe.rb` compared current collider inputs with all room foreground/ceiling artwork outlines and with each outline's occupied bounding rectangle. Full-artwork variants therefore include caps and colliderless artwork, in addition to changing blocker shape. Known object and door-part owner groups were retained; other caps had no owner exclusions. Sources used the same current ground positions, owner exclusions, radii (player 64, room fallback 48), and 32-sided circular boundary in every variant. The probe measures a proposed flat-artwork workload, not a complete restored historical implementation.

DragonRuby 7.21 Standard on Linux, HD off, offscreen software rendering. Geometry was prepared before timing. Each workload was warmed once; seven timing samples each performed three `Lighting.prepare` calls, with GC before each sample and variant order reversed on alternating samples. Values below are median milliseconds per call. The moving-lamp workload recomputes only the player polygon; the seven-light workload bypasses fixed-light reuse.

| Player position | Colliders: player / seven lights | Artwork outlines: player / seven lights | Artwork rectangles: player / seven lights |
| --- | ---: | ---: | ---: |
| 248, 220 | 1.919 / 15.926 | 2.251 / 21.975 | 1.876 / 19.856 |
| 170, 176 | 2.722 / 16.783 | 3.416 / 21.855 | 2.199 / 19.470 |
| 112, 80 | 2.691 / 16.990 | 4.090 / 22.849 | 4.867 / 21.532 |

Current inputs contain 54 collider rectangles / 216 edges. Full artwork produces 78 blockers / 383 outline edges, or 312 rectangle edges. Player polygons contained 141–186 vertices with colliders, 168–240 with artwork outlines, and 144–198 with artwork rectangles. No zero-distance hits occurred at these positions. Full outlines were slower at each position in this run; rectangles offered no consistent advantage over colliders. Individual samples varied substantially, so these observations do not establish a universal ratio.

These are geometry calculation timings, not whole-frame times or displayed FPS. They exclude artwork-geometry generation, cache comparisons/invalidation, receiving colors, drawing, and GPU completion. Removing receiving tint could save separate work, and animated outline changes could add cache misses; neither effect was measured here. The single diagnostic test completed without failure, and production behavior was unchanged.

## Current receiving-color cost

2026-10-19. A second temporary native probe, `mygame/tmp/receiver_cost_probe.rb`, timed the existing receiving and tint helpers without changing their behavior. The Ritual Gate room plus Player supplies 53 receiving sprites, 61 rectangular receiving bases, and seven enabled lights. The visible foreground count varies with camera position. Light polygons were prepared before receiving measurements, matching reuse of prepared geometry; each call still recalculates receiver colors for all lights and receivers as production does.

Same Linux DragonRuby 7.21 Standard, HD off, offscreen software-rendering environment as above. Each stage was warmed once, then measured in seven samples of ten operations, with GC before each sample and alternating forward/reverse stage order. Tint preparation operates on viewport-visible foreground sprites with precomputed colors. The combined stage calculates colors and prepares those tinted sprites in the same operation. Values are median milliseconds per operation, excluding GPU drawing.

| Player position | Visible foreground sprites | Receiving colors | Tint with existing colors | Colors plus tint | Moving-lamp polygon |
| --- | ---: | ---: | ---: | ---: | ---: |
| 248, 220 | 28 | 1.631 | 0.118 | 2.052 | 2.338 |
| 170, 176 | 42 | 1.889 | 0.175 | 2.340 | 2.427 |
| 112, 80 | 29 | 1.616 | 0.188 | 2.326 | 3.573 |

Independent stage medians need not add to the combined median; allocation and host timing varied between samples. This shows that calculating received colors has a measurable CPU cost, while applying known sprite RGB multipliers is a smaller preparation stage. The combined 2.05–2.34 ms is approximately 12–14% of a 16.67 ms frame budget in this local probe. It excludes room preparation, floor-light rendering, fading, draw-space conversion, submission, and GPU completion; it is not a whole-frame or FPS measurement.

The current method evaluates a small number of receiving samples against already prepared visibility polygons, then uses ordinary sprite color modulation. Evaluating the same visibility rule at more positions in Ruby adds queries. A GPU lightmap or shader is a different workload and may trade CPU queries for texture reads and rendering passes; these measurements do not establish whether such an alternative would be faster overall. A fair implementation comparison must preserve the desired receiving behavior and measure whole-frame cost on the same hardware. No alternate receiver renderer was benchmarked here. The diagnostic completed with one test passed and no failures; production behavior was unchanged.

## Future option: GPU receiver lighting and shadows

The user chose to retain the current approach. This section records possible future work; it authorizes no implementation or change to [ADR-0014](../adr/0014-use-collider-bases-for-lighting.md).

The game already draws a floor lightmap through DragonRuby render targets: Ruby prepares visibility polygons, textured triangles accumulate illumination, and a multiply pass shades the floor. On an accelerated graphics backend, the drawing and texture operations already use the GPU. “GPU lightmaps” could therefore refer to several different changes. [Current lightmap preparation](../../mygame/app/lighting.rb), [composition](../../mygame/app/render.rb)

| Possible change | What moves or changes? |
| --- | --- |
| Retain the current floor lightmap | No new shader is required. The CPU raycaster and object-level receiving remain. |
| Calculate receiver illumination in a shader | Replace some Ruby receiving queries and uniform sprite tints with texture sampling or per-fragment calculations. CPU visibility polygons can initially remain. |
| Calculate shadow visibility on the GPU | Replace or supplement the CPU polygon solver with another shadow algorithm, such as shadow-map comparisons or ray marching through blocker data. This is a separate, larger change. |

### What the installed SDK establishes

The inspected installation is DragonRuby 7.21. Its runtime's `assert_shaders_enabled!` checks both the Pro edition and `shaders=true` metadata. The project's current Standard edition therefore needs an edition change before using this native custom-shader path. This is a capability finding, not a request to upgrade. Sources: `$DRAGONRUBY_HOME/docs/version.txt` and `$DRAGONRUBY_HOME/docs/oss/dragon/runtime/require.rb`.

Current samples demonstrate HLSL fragment shaders on individual render targets, scalar integer/float uniforms, and multiple sampled render-target textures. Sample 03 uses `outputs[:target].shader = { path: ... }`; sample 04 supplies `uniforms`; sample 05 supplies three additional `textures` sampled alongside the scene texture in HLSL registers `t0`–`t3`. Sources: `$DRAGONRUBY_HOME/samples/14_shaders/03_shaders_on_render_targets/app/main.rb`, `04_uniforms/app/main.rb`, and `05_ripple_effects/app/main.rb` plus its `shaders/ripples.frag.hlsl`.

The installed `docs/api/outputs.md` also contains older GLSL/ShaderSim guidance using `shader_path`. The newer 7.16–7.19 changelog and HLSL samples establish a different experimental native API. Use those newer sources for a prototype; do not combine the two recipes. The inspected samples establish neither compute-shader access, multiple simultaneous output attachments, arbitrary texture-binding limits, nor cross-platform readiness. Source: `$DRAGONRUBY_HOME/docs/changelog.txt`.

### Inputs and work a receiver-lighting prototype would need

An implementation retaining CPU shadows could render each prepared polygon into a visibility mask, then let a fragment shader combine those masks with light positions, colors, ranges, and chosen falloff. Light data might use uniforms or a deliberately encoded texture; supported layouts and limits need a small SDK test. Texture masks are a proposed use of the demonstrated sampled-render-target API, rather than an existing project feature. [Current prepared polygons](../../mygame/app/lighting.rb)

The important data is each receiving pixel's meaning. Floor world coordinates can be reconstructed from camera placement. Upright artwork needs a mapping to its receiving surface: ground XY, and world Z if height-aware lighting is desired. That mapping could be drawn from simple face geometry or stored in auxiliary textures. Surface normals are optional inputs for facing/diffuse response. A shader reading only finished scene color and screen XY would retain the original projection ambiguity. [Foreground geometry problem](foreground-lighting-research.md), [surface-point and normal counterparts above](#conventional-counterparts-of-the-five-receiving-rules)

A receiver shader would write illumination or shaded artwork to a target, then compose it with the existing floor and scenery. Depth order, foreground-fade alpha, ambient caps, authored colors, and HUD placement still need explicit preservation. Keep HD disabled and size initial targets for the 320 × 180 raster. This is a proposed pipeline compatible with demonstrated fragment/texture operations, not a completed shader design. [Current compositor](../../mygame/app/render.rb), [HD decision](../adr/0013-keep-hd-disabled.md)

Moving visibility itself to the GPU additionally requires blocker data and a selected shadow method. Depth comparisons are an established option; ray marching through an occupancy or height representation is another possible design whose available sampling and precision must be checked. GPU execution alone adds no height model: finite-height shadows still require object volumes or suitable height/depth data, elevated lights, receiving positions, and matching visibility calculations. [Shadow-map reference](https://learn.microsoft.com/en-us/windows/win32/dxtecharts/common-techniques-to-improve-shadow-depth-maps), [height extension above](#adding-height-without-discarding-the-floor-plan)

The smallest capability test would use one render target, one additional receiver-data texture, one light, and the current CPU polygon mask. It would establish shader compilation, sampling, alignment, alpha, and composition before replacing room-wide receiving. Performance remains unmeasured: CPU query savings can be offset by data preparation, texture traffic, and added passes. The existing CPU timings cannot predict the result.
