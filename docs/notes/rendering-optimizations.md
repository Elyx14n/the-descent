# DragonRuby rendering optimization findings

Research date: **2026-10-05**. Sources inspected: the local DragonRuby **7.21
Standard** SDK and current project code. These are options for future work;
the proposed optimizations below are **not implemented**. No rendering
bottleneck has been demonstrated in the current three-entity, eight-wall scene.

## Reading the sources

Every `SDK:` path below is relative to `DRAGONRUBY_HOME`.
See [repository setup](../../README.md#first-time-setup-and-running-the-game)
if the SDK is not configured.

The accepted framing and text choices are recorded in
[the camera ADR](../adr/0001-viewport-sized-camera.md) and
[the resolution and fonts ADR](../adr/0002-reference-resolution-and-ui-fonts.md).

## What the game currently does

[CollisionPlayground.render](../../mygame/app/collision_playground.rb) performs
the following work each frame:

1. Access the viewport-sized `:scene` render target.
2. Build hashes for **all** walls, alongside the red tile.
3. Sort **all** props and the player by descending foot-position `y`.
4. Build a sprite hash for **every** entity, then combine the world primitives.
5. Find intersections with the world-space viewport.
6. Translate **only visible** primitives into screen coordinates and submit
   them to `:scene`. Debug borders follow the same filter/translation pattern.
7. Draw the scene as one viewport sprite, then draw HUD, countdown, and world
   annotation labels outside the scene target.

[Camera](../../mygame/app/camera.rb) only translates; it does not change artwork
dimensions. Its target follows `Grid.w`/`Grid.h` (currently 320 × 180 logical
pixels), regardless of world size. [Sprite.to_primitive](../../mygame/app/sprite.rb)
creates an anchored artwork hash; [Entity.collision_rect](../../mygame/app/entity.rb)
describes separate ground collision geometry.

This resembles `SDK: samples/07_advanced_rendering/16_camera_space_world_space_simple/app/main.rb`:
filter world objects, translate visible objects, render a viewport target, and
draw it as a sprite. That sample already creates its 500 world sprite hashes
once with `args.state.objects ||= ...`; it does not rebuild them each frame.

## Distinct ways to reduce work

### Filter before expensive preparation

If preparation becomes expensive, first find visible walls/entities using
cheap artwork bounds, then sort visible entities and create their primitives.
With `N` total objects and `V` visible objects, this still scans `N` bounds,
but can move primitive creation from `N` to `V` and entity sorting from
`N log N` to `V log V`. This is an analysis of the proposed pipeline, not a
measured speedup. The current code only saves translation/submission work for
offscreen objects. Sources: [current render method](../../mygame/app/collision_playground.rb);
`SDK: docs/api/geometry.md`, `find_all_intersect_rect`.

Cull by **artwork bounds**, including scale, foot padding, and anchors. A foot
collider can be offscreen while the sprite above it remains visible; decorative
props may have no collider at all. The SDK intersection functions account for
`anchor_x`/`anchor_y`. Sources: [sprite geometry](../../mygame/app/sprite.rb),
[prop configuration](../../mygame/app/prop.rb);
`SDK: docs/api/geometry.md`, `find_all_intersect_rect`.

If a future object exposes `render_rect`, the SDK's `using:` lookup must also
work on the **query**. The session's 7.21 runtime probe returned `[]` for a raw
viewport plus `using: :render_rect`, and found the intersecting object after
wrapping the viewport. Proposed shape, not a current project API:

```ruby
visible = Geometry.find_all_intersect_rect(
  { render_rect: camera.viewport_world }, objects, using: :render_rect
)
```

The documented example nests geometry on both query and collection objects.
Source: `SDK: docs/api/geometry.md`, `find_all_intersect_rect` and its `using:` example;
the query-lookup caveat was checked against the installed runtime.

### Reuse world primitive hashes

For unchanging walls and props, build world sprite hashes once and reuse them
for viewport queries. Visible screen-space copies still need camera translation.
Keep world hashes separate from translated hashes so camera motion does not
overwrite world coordinates. This is the simplest allocation-reduction option
suggested by `SDK: samples/07_advanced_rendering/16_camera_space_world_space_simple/app/main.rb`.

Invalidate such hashes when positions, dimensions, appearance, or source data
change. Preserve hot reload: the current [prop refresh](../../mygame/app/collision_playground.rb)
detects changed placement, override, and tilesheet constants. A future cache
must refresh with those changes too. Animated player frames still need updating.

### Retain sprite objects or use classes

A reusable hash or sprite object can be updated rather than allocated anew.
DragonRuby accepts class primitives; `attr_sprite` defines the sprite properties
for a class. The performance samples compare hash sprites with class sprites,
but do not establish a benefit for this game's tiny scene. Sources:
`SDK: docs/api/outputs.md`, Class Render Primitive and `attr_sprite`;
`SDK: samples/09_performance/01_sprites_as_hash/app/main.rb` and
`05_sprites_as_classes/app/main.rb` in the same directory.

`static_sprites` and other `static_*` output queues retain references across
frames, saving repeated queue submission. They **still draw their primitives
each frame**; they do not cache composed pixels. The static-class sample moves
its retained objects every tick. Sources:
`SDK: samples/09_performance/06_static_sprites_as_classes/app/main.rb`;
`SDK: docs/oss/dragon/outputs.rb`, static queues and clearing behavior.

A moving camera still requires updated screen coordinates and visible
membership. Moving entities still require depth-order updates. A retained queue
therefore needs explicit lifecycle/order management; retaining the current
world list once would not preserve current scrolling and overlap behavior.
This is a constraint derived from [the current camera](../../mygame/app/camera.rb)
and [render ordering](../../mygame/app/collision_playground.rb).

### Cache rendered pixels with render targets

A render target can combine unchanging content into a texture, then reuse that
texture without resubmitting its source primitives. This caches **pixels**,
unlike retained queues. Merely accessing `args.outputs[:name]` invalidates its
cached texture; store needed dimensions separately and access the target only
when rebuilding it. Sources: `SDK: docs/api/outputs.md`, Render Targets;
`SDK: samples/07_advanced_rendering/01_render_targets_combining_sprites/app/main.rb`.

The current `:scene` is accessed and redrawn every frame. Camera movement
changes its view, and player animation changes its contents, so a viewport
target cannot simply be built once. A separate cached static composition may
be useful later, but it needs an explicit invalidation strategy and layering
that preserves entity overlaps. Do not replace the viewport target with an
unbounded full-world texture: world growth would also grow that texture.
These are design implications, not measured SDK limits or implemented changes.

### Use spatial indexing only when the scan is slow

The SDK offers `Geometry.quad_tree_create` and
`Geometry.find_all_intersect_rect_quad_tree`. Its guidance is to use the latter
when `find_all_intersect_rect` is not fast enough. Build the index once for fixed
geometry and rebuild it when indexed rectangles change; account for moved or
removed objects and hot reload. A static index plus a small dynamic list may be
sufficient later. Source: `SDK: docs/api/geometry.md`, quad-tree functions and example.

### Consider custom drawing last

The specialized performance sample defines `draw_override` and calls
`ffi_draw.draw_sprite_ivar self`, reading instance variables directly. It adds
rendering-specific code and couples the object to that interface. Inspect and
measure this option only if simpler preparation and submission changes leave
a demonstrated cost. Sources:
`SDK: samples/09_performance/07_static_sprites_as_classes_with_custom_drawing/app/main.rb`;
`SDK: docs/oss/dragon/runtime/draw.rb`, `draw_sprite`.

## Existing useful choices to preserve

The project uses hash primitives and submits visible batches. `UI.box` and the
red tile already use `path: :solid`, the SDK's pre-cached solid texture. The
performance guide recommends these over array primitives, individual pushes,
and large numbers of ordinary solids. Sources: [UI](../../mygame/app/ui.rb),
[playground](../../mygame/app/collision_playground.rb);
`SDK: docs/guides/troubleshoot-performance.md`, Rendering Primitives and Solids.

Glyph sets are cached per font and size combination. Preserve the
[accepted text configuration](../adr/0002-reference-resolution-and-ui-fonts.md).
Avoid continually varying font sizes
for animation; the guide recommends rendering labels into targets when scaling
them. Sources: [UI](../../mygame/app/ui.rb),
[metadata](../../mygame/metadata/game_metadata.txt),
[font decision](../adr/0002-reference-resolution-and-ui-fonts.md);
`SDK: docs/guides/troubleshoot-performance.md`, Label size.

## Measurement plan and evidence boundary

1. Establish a repeatable baseline with current counts, then representative
   larger wall/prop counts. Include stationary views and a repeatable camera pan;
   record total/visible counts, debug-bounds setting, runtime, and display size.
2. Use `DR.benchmark` to compare Ruby work such as filtering, sorting, primitive
   construction, and translation on identical inputs. It compares blocks using
   either fixed iterations or fixed time. Source: `SDK: docs/api/runtime.md`, Benchmark.
3. Measure whole-frame behavior separately with frame timing and
   `DR.current_framerate_primitives` (which forwards to `framerate_diagnostics_primitives`).
   Inspect diagnostics such as draw-call count; Ruby microbenchmarks alone do
   not measure the complete rendering path. Sources: `SDK: docs/api/runtime.md`,
   Framerate Diagnostics; `SDK: docs/oss/dragon/runtime/framerate.rb`, forwarding implementation;
   `SDK: samples/09_performance/01_sprites_as_hash/app/main.rb`.
4. Change one thing at a time. Confirm visible output, depth order, camera pan,
   animation, and hot reload before comparing results. Keep only worthwhile
   improvements; do not add a spatial framework for the present room.

No baseline timings or comparative optimization results were collected for this
note. The viewport-sized target is established behavior; its smaller logical
area alone does not prove a frame-time reduction. HD rendering and display
scaling also mean logical dimensions are not a direct promise of physical GPU
work. Preserve the accepted rendering configuration and measure on the target
setup before making performance claims.
