# Raycast lighting: guided implementation

Date: 2026-10-18. Status: learning plan; lighting is not implemented by this note.

The PR's endpoint is a complete lighting system and test suite: authored room lights and a toggleable, circular player lamp, with sharp shadows and soft radial falloff. Implement it yourself in small commits, with quick checks and playtesting between them. Ask for focused help at the current checkpoint rather than working through a full solution up front.

The supplied HTML is preserved in the [reference appendix](#reference-snippet). It is the algorithm reference, not code to port literally: the game uses Ruby, world Y increases upward, and drawing goes through a camera and render targets.

## Building blocks and ownership

| Primitive | Meaning / analogy | Producer → consumer |
| --- | --- | --- |
| Blocker segment | An edge that stops a beam; a fence | Room's selected scenery through `SpriteGeometry.edges` → raycaster |
| Emitter | A bulb's position, radius, color, intensity | Room lights or Player → lighting calculation |
| Ray | A probe sent from an origin in one direction; it extends beyond the point defining its direction | Raycaster → intersection calculation |
| Hit | The nearest obstruction in front of the origin, with a position and distance parameter | Intersection calculation → visibility polygon |
| Visibility polygon | Ordered boundary points enclosing everywhere the bulb can reach; a stencil | Raycaster → lighting renderer |
| Lightmap | A sheet of illumination combined with the scene | Lighting renderer → scene compositor |

Suggested homes and dependency direction:

- **Existing geometry:** [SpriteGeometry](../../mygame/app/sprite_geometry.rb) already transforms generated outlines into world-space edges. Reuse it; no asset-generation changes are needed. [ADR-0012](../adr/0012-continuous-occluder-queries.md) describes the source geometry and its separation from fade selection.
- **Inputs:** Room selects blockers and exposes enabled authored emitters. Player produces its lamp data. RoomPreview combines these into plain frame fields such as `light_emitters` and `light_blockers`; Render continues to consume frame data without reaching into Room or Player.
- **Math:** add `mygame/app/raycasting.rb` for stateless intersection and visibility-polygon calculations. It consumes ordinary geometry, without DragonRuby outputs, input, or camera state.
- **Drawing:** add `mygame/app/lighting.rb` for polygon drawing, radial falloff, and lightmap preparation. Render calls it when composing the world scene. Keep the raycaster independent of drawing.
- **Tests:** add deterministic math coverage under `mygame/tests/raycasting_test.rb`, then lighting integration coverage under `mygame/tests/lighting_test.rb` and relevant existing suites.

Keep geometry in world coordinates until drawing. Reuse the installed SDK and existing occluder data; add no gems or runtime libraries. Consult `$DRAGONRUBY_HOME/docs/api/outputs.md` and `samples/07_advanced_rendering/14_triangles` when reaching the drawing checkpoint, and verify the needed operations in the installed Standard build.

## Implementation ladder

Each step is a potential commit. Stop at its checkpoint before adding the next piece.

### 1. Connect the inputs

Expose enabled room emitters and lighting blockers through the frame interface; add the player's circular emitter controlled by `lamp_on`. Select all non-floor scenery independently of fading. Carry enough owner identity to omit an emitter's own artwork and mounted host group from that emitter's blockers. Actors do not cast shadows in this version.

Use active sprites so door states and light animation supply current geometry. Include ceiling and mounted artwork once. Do not select blockers only from on-screen artwork: an offscreen obstacle or light can affect the visible region.

**Checkpoint:** existing debug markers and outlines agree with the selected emitters and blockers, including door/light changes. Verify input production without illumination yet.

Room-side progress (2026-10-18): `Room#render_data` now supplies `light_sources` (the implementation's name for emitters) and `light_blockers`. Each blocker is `{ owner_ids: [...], sprite: ..., edges: [...] }`; each edge is `{ x: ..., y: ..., x2: ..., y2: ... }` in world coordinates. A source carries `ignore_owner_ids` for its own group. Later, when casting for that source, skip a blocker if the two owner-ID arrays overlap. Other lights remain blockers. Standalone ceiling pieces have empty owner arrays and still block light.

Read `prepare_light_blockers` for membership/ownership and `light_blockers` for fresh edge production in `mygame/app/room.rb`. Both source and blocker helpers are private; consume their frame fields. B now draws the frame's visible blocker edges in magenta and enabled sources as green squares. The player lamp is still your next task within this step. Source radius and color still contain authored values; illumination defaults belong to the later lighting work.

Room-side and diagnostic verification: all 161 native tests and `bin/rubocop --cache false` pass. Regressions cover floor exclusion, complete scenery membership, source snapshots and owner metadata, refreshed door/light edges, camera-translated magenta outlines, and enabled emitter markers hidden when debugging is off. Manual diagnostic playtesting remains pending: press B, move the camera, and toggle a light and door to inspect the updated overlay.

### 2. Intersect one ray with one segment

Build the smallest deterministic geometry function and its tests. Think of finding where a laser pointer meets a fence. A valid hit is forward along the ray and lies within the finite segment; retain a parameter that lets you compare hits on the same ray.

Adapt the math rather than copying the reference's division by `r_dx`: vertical rays make that unsafe. Its normalized-direction parallel check also misses opposite-direction parallel segments. Define a small numerical tolerance; return no hit for parallel/collinear pairs and degenerate rays or segments in this first version.

**Checkpoint:** tests cover vertical/horizontal rays, diagonal hits, opposite-direction parallel segments, segment endpoints, behind-origin intersections, misses, near-parallel cases, and zero-length inputs. Inputs remain unchanged.

### 3. Construct one visibility polygon

Follow the reference's sequence: collect unique endpoints, probe toward each endpoint and just beside it, retain each ray's nearest hit, then order the hits around the emitter. Begin with its angular offset of `0.00001` radians. Add a closed square enclosing the emitter's radius so unobstructed rays terminate; the radial falloff will impose the circular range later.

Draw a debug outline first. Think of walking around the bulb and recording the first fence visible in each direction. Handle an empty/degenerate result without trying to draw a polygon.

**Checkpoint:** tests and outlines show nearest-hit selection, corner shadow boundaries, disconnected blockers, concave shapes, duplicate endpoints, and an unobstructed bounded region. Move the origin near edges and corners to look for instability.

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

User-supplied reference, preserved unchanged. No external attribution was supplied.

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
