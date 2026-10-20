# Player jitter near foreground objects

Investigation on 2026-10-21, following the [sampling correction](conventional-pixel-art-rendering-sources.md#follow-up-nearest-scene-presentation-and-downsized-artwork). The user confirms the blur is fixed. Remaining jitter affects the player's position or outline during diagonal movement near the room perimeter, **including with a visible gap from the player's feet to the wall**. The live comparison subsequently isolated camera clamping; the preview now uses the demonstrated always-follow mode under [ADR-0017](../adr/0017-keep-preview-camera-on-player.md).

The final always-follow cleanup also removes Camera’s clamp option and stored room bounds; initialize it with `Camera.new(x:, y:)`. Earlier comparison commands and clamp arguments below document the investigation at those checkpoints.

Preserve the confirmed baseline: metadata nearest sampling, pixel-art filtering only for downsized source artwork, HD off, native 320 × 180 raster, and existing simulation/interpolation. Avoid mixing additional corrections into a visual comparison without establishing which reported symptom they address.

## Isolated findings

### Transparent-pass brightness discontinuity

`tmp/fade_pass_order_probe.rb` freezes geometry, camera, source art, and opacity. A white square with `a: 128` sits over a grey floor (`100`); the player is elsewhere and does not overlap it. Only the square's depth changes, moving it between the scenery runs before and after the direct player draw.

Across six warmed captures, the square's sampled RGB alternates between **178 before the player** and **114 after the player**. The transparent post-player target is consumed using ordinary alpha, multiplying its already weighted RGB again. Consuming scene targets with explicit premultiplied alpha produces **178 in both runs**, with no geometry change. This corroborates the earlier alpha probe and is a reproducible color discontinuity around translucent artwork. It does not establish a geometric displacement of the player in the user's visible-gap case. No alpha change has been added to production during this investigation.

### Rounding the nearest scenery destination is not a demonstrated fix

`tmp/fade_motion_probe.rb` moves a frozen player and camera diagonally past a translucent wall and cap. Compare normal fractional scenery presentation with explicitly rounded final scenery destinations, retaining metadata nearest sampling. All **94 warmed frame pairs are pixel-identical**. Thus adding another destination rounding operation is not supported as a correction by this reproduction. It also cannot remove ordinary native-grid diagonal stepping.

### A distinct contact/facing bug, parked

`tmp/fade_player_trace.rb` runs 800 callbacks with injected timestamps and diagonal inputs around the actual room, recording presented world coordinates, final player sprite coordinates, source frame, tint, facing, fixed-step count, and active fade count. Disabling fading preserves the following right-wall failure:

- Holding northeast approaches the right-side collider at `x=320` with an 8-pixel-wide foot collider.
- The player center briefly reaches `x=316.145815...`, penetrating by about **0.146 pixels**.
- The next horizontal update resolves backward to `x=316`, and `movement_facing` interprets that correction as westward movement. The rendered row briefly switches **east → west → north** while the input remains northeast.
- Final drawing X remains rounded to 284 during the small correction; the sudden source-row change is an actual outline jump rather than a whole-screen position reversal.

The installed SDK's documented default `intersect_rect?` tolerance is `0.1`; the native probe also shows `find_all_intersect_rect` ignoring shallow overlaps and including exact edge contact when explicitly given zero tolerance. A temporary correction used a zero-tolerance broad phase plus positive overlap along the perpendicular axis, preserving sliding. A regression across four wall faces, walking/sneaking, and four fractional approach phases failed before that correction and passed after it. The full temporary branch passed **196 native tests**; replaying the routes removed the recorded collision reversals.

The user subsequently confirmed jitter also happens with a visible gap. This contact bug therefore cannot explain the whole report. Its actor/test changes were removed from the working tree and retained as `/tmp/descent-contact-fix.patch` for a separate correction. The patch's test also needs two loop literals extracted to local variables to satisfy RuboCop. Do not report that branch's 196-test count as the current sampling baseline's test count (195).

## Live comparison prepared for the reported case

Offscreen captures establish numeric and raster invariants, but have not reproduced an extra free-movement position reversal matching the user's observed jitter. The next comparison separates three remaining influences on the same visible-gap route. It is an ignored, opt-in script; production camera, fade rules, and animation code remain unchanged.

```sh
bin/rake run -- --eval tmp/fade_jitter_comparison.rb
```

**F5** cycles through one isolated treatment at a time:

1. **NORMAL**: confirmed sampling baseline.
2. **FADING OFF**: no fade units; camera, collision, lighting, and animation continue normally.
3. **CAMERA UNCLAMPED**: ordinary fading/animation; camera follows the presented player outside the room's normal clamp. Black area beyond the room is expected in this diagnostic.
4. **ANIMATION FROZEN**: ordinary fading/camera; player source frame stays at the first frame of the selected clip, while movement and facing still update.

The script displays the active mode and player/camera coordinates. It changes only one treatment relative to normal, rather than accumulating toggles. Avoid contact when comparing the reported gap case. Allow initial fade transitions to settle after switching modes. Exit this process and run the normal command to remove all overrides.

A 120-frame offscreen smoke run successfully exercised all four modes. Invocation for that check:

```sh
SDL_VIDEODRIVER=offscreen SDL_AUDIODRIVER=dummy LIBGL_ALWAYS_SOFTWARE=1 \
  bin/rake run -- --eval tmp/fade_jitter_comparison.rb --probe-smoke true
```

The user reports **CAMERA UNCLAMPED fixes the diagonal player jitter**, and clarifies the affected region is the room perimeter and the entire corner areas rather than fade units themselves. This is consistent with the old camera limits: in a 352 × 384 room, a 320 × 180 viewport clamps its center below X=160, above X=192, below Y=90, or above Y=294. Those broad peripheral regions make the player traverse the native raster instead of staying at a fixed drawing anchor. In diagonal travel, mismatched fractional X/Y phases can stagger those pixel steps.

## Normal-preview implementation

The preview now uses `Camera.new(bounds: room.bounds, clamp: false)`. The reusable camera's default remains bounded, and its drawing copies preserve the option. The view can extend beyond room walls, matching the successful comparison rather than introducing a new raster or a movement correction. The contact/facing patch and transparent-target alpha change remain deferred so this implementation retains one demonstrated correction.

The new corner-input regression failed against the old preview: its camera remained `(160, 90)` while the moving player was approximately `(48.8321, 81.2071)`. After the policy change, all 197 native tests pass, including 48 diagonal input/interpolation callbacks spanning the four actual-room corners. Final actor placement stays `(160, 66)` throughout. Default-clamp coverage remains intact, including small-world centering, boundary transitions, and coordinate conversion.

An 80-frame native renderer playback visited all four corners; capture-time actor positions were `(160, 66)` at each, and selected captures were inspected. The ignored reproduction is `tmp/room_corner_camera_probe.rb`, with captures `tmp/room-corner-camera-N.png`. These numeric/capture checks complement the user's successful comparison; normal-preview perimeter framing and sustained visual quality still need a final playtest.


## Follow-up: scenery jitter with the always-follow camera

The user confirms the player no longer jitters, but reports short bursts of tiny camera jitter during diagonal movement anywhere. They cannot reliably distinguish backward movement from uneven forward steps by eye. The normal-preview change therefore fixes the demonstrated player symptom, not the complete rendering report.

`tmp/diagonal_camera_probe.rb` isolates one remaining artifact using the production renderer, an always-follow camera, a frozen player, and a stationary 4 × 4 red marker. There are no walls, fading, lighting, animation changes, collisions, or callback-time variation. The camera advances by `sqrt(0.5)` along both axes per captured frame.

- Starting at `(500.125, 500.5)`, the warmed baseline gives 23 diagonal steps, 17 horizontal-only steps, and 17 vertical-only steps across 57 transitions. There are no backward steps. The X/Y fractional-phase difference alone makes straight diagonal world movement zigzag across the raster.
- Starting with equal fractional coordinates gives 42 diagonal steps and 17 stationary frames across 59 transitions. There are no axis-only or backward steps. Thus starting position can change the apparent motion even with identical velocity and frame timing.

This is a candidate explanation for the new report, not confirmation that these captures reproduce the user's perceived bursts. Native nearest-neighbor presentation exposes this movement quantization; the existing fractional scene remainder does not create finer steps after rendering into the native 320 × 180 framebuffer. Explicitly rounding the same remainder was already shown to leave captures unchanged.

### Opt-in comparison

```sh
bin/rake run -- --eval tmp/diagonal_camera_comparison.rb
```

F5 switches **NORMAL** / **DIAGONAL STEPS TOGETHER**. Only scenery raster placement changes; the player remains drawn at its ordinary centered anchor. The experimental mode rounds traveled distance from the start of each straight diagonal segment and applies that same step count to both axes. Both modes receive identical two-pixel guards around the scenery targets to cover the experimental origin's possible one-pixel difference. Source filtering, lighting, fading, interpolation, movement, and the native raster remain the same. Exiting removes all overrides; this is an ignored diagnostic, not a production fix.

The mismatched-phase capture changes to 41 diagonal steps and 16 stationary frames across 57 transitions, eliminating all 34 axis-only steps. The equal-phase case remains 42 diagonal steps and 17 stationary frames. The red marker retains exactly 16 pixels in every measured frame. Submitted player anchors remain `(160, 66)` throughout all 240 callbacks. A native rule probe checks 10,240 positions across four diagonal directions, walking/sneaking, and 16 initial phase combinations: diagonal steps stay paired, never reverse during the straight segment, and remain within one world pixel of the precise camera. A separate 120-frame actual-room smoke run switches successfully through both modes.

This experiment still has whole-pixel move/hold cadence, and a direction change reanchors its diagonal segment. Turning, wall sliding, repeated short inputs, stopping, and real display timing require playtesting before any production adoption. It is deliberately not folded into `Camera` or recorded as an accepted motion policy. Existing automated results for production remain 197 native tests; the diagnostic checks are additional isolated evidence, not new project tests. The confirmed blur, prop sampling, and player-centering corrections remain in place.


## Normal renderer promotion

The user confirms **DIAGONAL STEPS TOGETHER eliminates the reported camera jitter**. The behavior is now part of normal composited rendering under [ADR-0018](../adr/0018-pair-diagonal-camera-pixel-steps.md); launch with `bin/rake run`, without the diagnostic script or F5 toggle.

`CameraScroll` retains the tested segment-based placement algorithm. Camera owns an instance shared with its interpolated drawing copies; `for_presentation` also initializes history for cameras surviving hot reload. `for_compositing` uses that history for the scenery's native raster origin. Render presents scenery targets at `(0, 0)` and retains precise translation only for direct actors, so no fractional scenery blit or padding is needed. Scene/lightmap targets are 320 × 180. Preview history collapse resets the camera phase for teleports, respawns, reloads, and discarded clock intervals.

`tmp/camera_promotion_reference.rb` recorded the user-tested diagnostic before production changed. `tmp/camera_promotion_probe.rb` subsequently recorded normal production with the same fixed timestamps, movement inputs, four corner routes, source animation, lighting, and fading. All 96 callbacks submit player anchors `(160, 66)`. Excluding the top 20 HUD rows (live FPS text differs between runs), 95 captured frames are pixel-identical; frame 8 has one pixel at image coordinates `(185, 51)` changing from RGB `(9, 8, 10)` to `(9, 8, 9)`. This is the strict comparison result, refining the initial spot-check description that only FPS text differed. There is no measured geometry displacement between the two implementations.

Native regressions cover the production algorithm, paired scenery motion across interpolation copies, unchanged direct actor placement, source-camera immutability, native target coverage, and existing depth/lighting dependencies. Rule coverage includes four diagonal directions, walking/sneaking, differing and negative fractional phases, pauses, speed changes, repeated turns, wall sliding, history resets, and display-scale changes. The source-camera copy regression explicitly emulates a camera constructed before hot reload. Existing world/collision/fade rules remain unchanged; the parked contact/facing and premultiplied-alpha corrections are not part of this promotion.


## Always-follow camera cleanup

After the paired-step implementation, the user removed clamping entirely. Camera now initializes from explicit `x/y` coordinates and retains no room bounds. RoomPreview initializes it at the player position instead of constructing a room-centered camera and immediately following the player. Runtime/test/benchmark callers use the position API; the obsolete clamp keyword and five clamping-specific tests are removed. Actor alignment for fractional screen positions is retained as a stationary-view regression. Room bounds and viewport culling remain separate responsibilities. [ADR-0017](../adr/0017-keep-preview-camera-on-player.md) records the current policy; earlier `Camera.new(bounds:, clamp:)` examples above are historical.

The cleanup passes all 197 remaining native tests and RuboCop. A 96-frame four-corner renderer playback keeps the player anchor fixed and is pixel-identical to the pre-cleanup production captures outside the live HUD text.
