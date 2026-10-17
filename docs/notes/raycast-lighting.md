# Raycast lighting: guided implementation

Date: 2026-10-18. Status: learning plan; lighting is not implemented by this note.

The PR's endpoint is a complete lighting system and test suite: authored room lights and a toggleable, circular player lamp, with sharp shadows and soft radial falloff. Implement it yourself in small commits, with quick checks and playtesting between them. Ask for focused help at the current checkpoint rather than working through a full solution up front.

The main references are Nicky Case's [Sight & Light guide](https://ncase.me/sight-and-light/) and the supplied HTML preserved in the [reference appendix](#reference-snippet). Follow their names and vocabulary while adapting the implementation to Ruby, upward-increasing world Y, and the game's camera/render targets. The supplied HTML is a user-provided variant; the guide also explores fuzzy shadows, which remain outside this PR.

## Building blocks and ownership

| Primitive | Meaning / analogy | Producer → consumer |
| --- | --- | --- |
| Line segment | A finite edge that stops a ray; a fence | Room's selected scenery through `SpriteGeometry.edges` → raycaster |
| Light source | A bulb's position, radius, color, intensity; also called an emitter in this note | Room lights or Player → lighting calculation |
| Ray | A probe sent from an origin in one direction; it extends beyond the point defining its direction | Raycaster → intersection calculation |
| Intersection | Where a ray meets a line segment; retain the closest intersection along each ray | Intersection calculation → sight polygon |
| Sight polygon / visibility polygon | Ordered intersection points enclosing everywhere the source can reach; a stencil | Raycaster → lighting renderer |
| Lightmap | A sheet of illumination combined with the scene | Lighting renderer → scene compositor |

Suggested homes and dependency direction:

- **Existing geometry:** [SpriteGeometry](../../mygame/app/sprite_geometry.rb) already transforms generated outlines into world-space edges. Reuse it; no asset-generation changes are needed. [ADR-0012](../adr/0012-continuous-occluder-queries.md) describes the source geometry and its separation from fade selection.
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

Expose enabled room emitters and lighting blockers through the frame interface; add the player's circular emitter controlled by `lamp_on`. Select all non-floor scenery independently of fading. Carry enough owner identity to omit an emitter's own artwork and mounted host group from that emitter's blockers. Actors do not cast shadows in this version.

Use active sprites so door states and light animation supply current geometry. Include ceiling and mounted artwork once. Do not select blockers only from on-screen artwork: an offscreen obstacle or light can affect the visible region.

**Checkpoint:** existing debug markers and outlines agree with the selected emitters and blockers, including door/light changes. Verify input production without illumination yet.

Room-side progress (2026-10-18): `Room#render_data` now supplies `light_sources` (the implementation's name for emitters) and `light_blockers`. Each blocker is `{ owner_ids: [...], sprite: ..., edges: [...] }`; each edge is `{ x: ..., y: ..., x2: ..., y2: ... }` in world coordinates. A source carries `ignore_owner_ids` for its own group. Later, when casting for that source, skip a blocker if the two owner-ID arrays overlap. Other lights remain blockers. Standalone ceiling pieces have empty owner arrays and still block light.

Read `prepare_light_blockers` for membership/ownership and `light_blockers` for fresh edge production in `mygame/app/room.rb`. Both source and blocker helpers are private; consume their frame fields. B draws the frame's visible blocker edges in magenta and enabled sources as green squares. RoomPreview appends the player's enabled `light_source` once when assembling the frame, independently of debugging. Room source radius and color still contain authored values; illumination defaults belong to the later lighting work.

Room-side, geometry, and diagnostic verification: all 168 current native tests pass. Regressions cover floor exclusion, complete scenery membership, source snapshots and owner metadata, refreshed door/light edges, camera-translated magenta outlines, enabled emitter markers, the lamp sight outline, fractional origins, angle wraparound, and HD-off configuration. The user confirmed the basic outline works. Manual confirmation of the restored bucket version remains pending: press B, move the camera, and toggle the lamp, a room light, and a door to inspect the overlay.

### 2. Intersect one ray with one segment

Start with `get_intersection(ray:, segment:)` and its tests, using the endpoint shapes above. Think of finding where a laser pointer meets a fence. Following the supplied snippet, accept `t1 >= 0` and `0 <= t2 <= 1`, including endpoints; return `t: t1` so you can compare intersections along the same ray. The guide's prose uses strict inequalities, but its endpoint-directed approach and the supplied snippet need endpoint intersections.

Adapt the math rather than copying the reference's division by `r_dx`: vertical rays make that unsafe. Its normalized-direction parallel check also misses opposite-direction parallel segments. Define a small numerical tolerance; return no hit for parallel/collinear pairs and degenerate rays or segments in this first version.

**Checkpoint:** tests cover vertical/horizontal rays, diagonal hits, opposite-direction parallel segments, segment endpoints, behind-origin intersections, misses, near-parallel cases, and zero-length inputs. Inputs remain unchanged.

### 3. Construct one visibility polygon

Follow the reference's sequence: collect unique endpoints, probe toward each endpoint and just beside it, retain each ray's nearest hit, then order the hits around the emitter. Begin with its angular offset of `0.00001` radians. Add a closed square enclosing the emitter's radius so unobstructed rays terminate; the radial falloff will impose the circular range later.

Draw a debug outline first. Think of walking around the bulb and recording the first fence visible in each direction. Handle an empty/degenerate result without trying to draw a polygon.

**Checkpoint:** tests and outlines show nearest-hit selection, corner shadow boundaries, disconnected blockers, concave shapes, duplicate endpoints, and an unobstructed bounded region. Move the origin near edges and corners to look for instability.

Prototype progress (2026-10-18): `Raycasting.get_sight_polygon` feeds a red closed lamp outline through `RoomPreview#add_lamp_sight_polygon`. The helper converts blockers overlapping the lamp square into endpoint segments, adds four square border segments, and connects consecutive returned intersections back to the first. Only the magenta blocker overlay is viewport-culled. The lamp outline disappears when the lamp is off. Native preview regressions verify closure, movement, camera-independent world geometry, and preservation of the other debug overlays. Geometry regressions compare sampled polygon distances with the readable reference intersection method, including fractional origins, concave/disconnected outlines, negative-angle wraparound, source-on-segment cases, and short axis-aligned directions. Broader lighting integration coverage and manual shadow-edge playtesting are still needed before calling the lighting test suite complete.

#### Performance checkpoint before filling the light

The first all-room implementation tested 387 segments against 774 rays: 299,538 intersection attempts per source per frame. On the local Linux DragonRuby 7.21 Standard installation, its Ruby preview preparation took roughly 630–678 ms in three fixed positions. The user reported about 10 FPS in the smaller window and 4 FPS maximized. HD-off with optimizations restored 60 FPS in their playtest, but reverting every optimization returned sub-10 FPS. [ADR-0013](../adr/0013-keep-hd-disabled.md) makes HD-off mandatory; it does not remove the need to bound raycasting work.

The earlier bucket version retained three changes: selecting sprites intersecting the lamp square, preparing segment numbers once per calculation, and using 64 temporary direction buckets to select candidate segments. Buckets do **not** quantize or reduce the endpoint-directed rays; candidates still pass the same intersection inequalities. The numeric loop allocates only the nearest intersection for each ray. No persistent cache, invalidation protocol, segment-clipping API, or extra runtime dependency remains. `get_intersection` stays readable as the reference/test oracle; the hot loop uses the equivalent determinant formulas.

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

First prove polygon filling in the installed DragonRuby build. A visibility polygon can be filled as triangles joining the emitter to adjacent boundary points, including the closing pair. Then apply radial falloff only inside that shape. Think of the polygon as a stencil and the falloff as paint applied through it.

Inspect `mygame/sprites/light_mask.png`, including its alpha/color channels, before reusing it; it may need a different interpretation than a white light texture. Establish this with a tiny render-target experiment. Keep this graphics experiment separate from the raycaster.

**Checkpoint:** one light fades smoothly to zero at its radius; shadows remain sharp. Check the center, edge, blocked region, and camera movement. Verify graphics support before expanding to all lights.

### 5. Composite the full scene

Accumulate colored contributions from all enabled emitters into a lightmap with an ambient baseline, then multiply it with the completed world scene. Keep light contributions confined to their visibility polygons. Multiple lights should brighten overlaps without darkening one another.

Integrate after existing Y sorting and foreground fading, before diagnostics and HUD. Transform every polygon vertex with the same drawing-camera snapshot as the scene, accounting for drawing alignment; the existing rectangle conversion helpers do not automatically transform every vertex. Rebuild or clear the lightmap each frame so toggles and movement leave no trails.

**Checkpoint:** lights overlap correctly; lamp and room-light toggles remove their contributions immediately; camera scrolling keeps shadows attached to scenery. HUD and diagnostic colors remain readable. Foreground fading does not change light blockage.

### 6. Complete regression coverage and playtest

Cover moving lamp origins, enabled states, door variants, light animation, per-emitter owner exclusions, offscreen lights/blockers, reload, and frames with no lights. Keep numerical geometry tests independent of the SDK's renderer; integration checks should establish frame data and rendering behavior without pretending to prove visual quality.

Run narrow native tests while iterating, then `bin/rake test` and `bin/rubocop` for the completed PR. Use the [DragonRuby testing reference](../../.agents/skills/dragonruby-development/references/testing.md) for project commands.

**Checkpoint:** automated checks pass. Manually inspect mounted flames, corner leaks, door transitions, lamp toggles, overlapping colors, darkness readability, and camera motion. Measure the completed room before considering caching or spatial indexing. Record automated results separately from playtest observations.

## Initial defaults and boundaries

- Use sharp shadow edges and soft radial falloff; the lamp emits in all directions.
- Start with radius 96 world pixels, intensity 1, white light, and ambient brightness 12%. Positive authored radii and authored colors override these defaults; zero radius and empty color use defaults. Intensity controls each light's contribution.
- Place the player emitter 16 world pixels above its ground anchor, scaled with the actor. Treat this as an initial tuning position rather than matching every animation frame.
- Exclude the emitter's own artwork and mounted host group only for that emitter. Other scenery still blocks it. This deliberate approximation lets mounted flames escape supporting outlines; inspect the resulting wall illumination during playtesting.
- Blockers use active generated geometry regardless of temporary foreground fade opacity. Do not use foot colliders as light-blocking silhouettes.
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
