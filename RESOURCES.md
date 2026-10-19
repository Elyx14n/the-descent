# Coordinate and Rendering Resources

## Knowledge

- [The Descent glossary](GLOSSARY.md), [Camera](mygame/app/camera.rb), [Render](mygame/app/render.rb), and [Sprite](mygame/app/sprite.rb).
  Primary evidence for our project terms and actual coordinate flow. Read the fractional presentation snapshot, compositing snapshot, and final actor alignment separately; the default camera conversion can still use a snapped camera offset.
- [DragonRuby Grid documentation](https://docs.dragonruby.org/#/api/grid).
  Official reference for the logical canvas, origin, aspect size, and render scale. The installed 7.21 copy is `$DRAGONRUBY_HOME/docs/api/grid.md`; it includes the 320 × 180 aspect-size table. Some older prose still assumes the default 1280 × 720 canvas, so check our metadata rather than copying those dimensions.
- [DragonRuby sprite/output documentation](https://docs.dragonruby.org/#/api/outputs).
  Official reference for destination coordinates, anchors, source-image crops, sampling, and render targets. Installed reference: `$DRAGONRUBY_HOME/docs/api/outputs.md`. Use for the distinction between `x/y` and `source_x/source_y`, and between logical target dimensions and image sampling.
- [DragonRuby camera-space/world-space sample](https://docs.dragonruby.org/#/samples/advanced-rendering).
  Installed source: `$DRAGONRUBY_HOME/samples/07_advanced_rendering/16_camera_space_world_space_simple/app/main.rb`. Demonstrates camera conversion and a viewport scene target; our raster-alignment policy extends it rather than coming from that sample unchanged.
- [SDL: logical rendering presentation](https://wiki.libsdl.org/SDL3/SDL_SetRenderLogicalPresentation).
  Primary reference for logical rendering dimensions being distinct from the actual presentation resolution. Use for why enlarging a window need not enlarge the world view. This is supporting background, not a claim that our Ruby code calls this function directly.
- [Godot: viewport and canvas transforms](https://docs.godotengine.org/en/stable/tutorials/2d/2d_transforms.html).
  Primary explanation of successive coordinate transforms and inverse transforms. Godot's names and full transform chain differ from ours; use for the general principle, not as our project's glossary.
- [Godot: pixel snapping](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-snap-2d-transforms-to-pixel).
  Primary corroboration of the crispness versus movement-step tradeoff. This is evidence that drawing alignment is established practice, not a prescription for our specific DragonRuby renderer.
- [Our renderer captures and findings](docs/notes/single-scene-sampling-sources.md#follow-up-direct-actor-blur-at-camera-boundaries).
  Project evidence for fractional-position blur, final actor alignment, and the limitations of the earlier following-camera probe. Consult when distinguishing demonstrated behavior from a sampling hypothesis.
- [W3C PNG image model](https://www.w3.org/TR/png-3/#4Concepts) and [W3C SVG introduction](https://www.w3.org/TR/SVG2/intro.html).
  Primary specifications for a raster image's pixel-sample representation and vector shapes/paths. Use to distinguish an asset's representation from the raster output of rendering; a raster does not need to have a vector origin or be saved as a file.
- [Adobe: vectorize images using Image Trace](https://helpx.adobe.com/illustrator/desktop/manage-objects/traces-mockups-symbols/trace-images-to-convert-raster-into-vector-artwork.html).
  First-party example of deriving vector paths from a raster image. Use to distinguish vectorization from rasterization; the lesson does not require Illustrator or recommend buying it.

### Hands-on game-math practice

Selected for the user's stated verbal/spatial preferences and strength in symbolic algebra. Exercises below are suggested applications to our code, not claims that these sites provide DragonRuby-specific assignments. Use one small experiment at a time, with code and sliders handling arithmetic.

- [Freya Holmér: Math for Game Devs — vectors and dot product](https://www.youtube.com/watch?v=fjOdtSu4Lm4), then [interpolation and point physics](https://www.youtube.com/watch?v=tjTRXzwdU6A).
  Creator's course recordings, with assignment/lecture links in the video descriptions. Use as a structured game-math course, pausing to reproduce a single idea in a small Ruby sketch rather than completing the whole series before applying it. Local connections: `Actor#normalize_movement`, camera translation, and `RoomPreview.presentation_position`. Practice: draw a movement vector and compare its raw versus normalized direction; then draw previous/current positions with an interpolated marker between them.
- [Immersive Linear Algebra: vectors](https://immersivemath.com/ila/ch02_vectors/ch02.html) and [dot product](https://immersivemath.com/ila/ch03_dotproduct/ch03.html).
  Author-hosted text with interactive figures; the vectors chapter explicitly starts with a moving ball's direction and speed. Best for manipulating diagrams before reading the equations. Practice: move vector endpoints, describe subtraction as displacement between points, and keep direction separate from magnitude. Connect normalization to diagonal movement; dot-product facing tests are a future application, not an implemented Witness system.
- [Desmos Graphing Calculator](https://www.desmos.com/calculator), with [official sliders and movable-points guide](https://help.desmos.com/hc/en-us/articles/202529069-Sliders-and-Movable-Points-in-a-Graph).
  A formula laboratory rather than a course. Use sliders to test symbolic camera translation, interpolation, and shaping functions without doing arithmetic by hand. Practice: hold a world point fixed while varying camera position, or vary the interpolation parameter and describe the marker's path. Use single-letter variables or supported subscript notation in Desmos rather than assuming our prose-like variable names parse as single symbols.
- [Red Blob Games: 2D Visibility](https://www.redblobgames.com/articles/visibility/).
  Interactive draggable light/visibility origin and wall playground, with ray-casting and angular-sweep explanations. Closest to the geometry behind our light polygons and occluders; its full sweep implementation is not identical to our endpoint ray caster. Practice: predict the first blocking wall before dragging a light around a corner, then relate the hit point to `origin + t × direction`.
- [The Book of Shaders: shaping functions](https://thebookofshaders.com/05/).
  Author-created browser examples and code exercises for linear and curved mappings. Use the browser editor to explore interpolation, clamping, step, and smoothstep; adopting shaders in DragonRuby is not required. Practice: reshape a curve, describe its steep and flat regions verbally, then relate the curve to `ForegroundFade.multiplier` and its smoothstep polynomial. Start after interpolation is comfortable.
- [Gaffer On Games: Fix Your Timestep!](https://gafferongames.com/post/fix_your_timestep/).
  Original developer article about fixed-step simulation, accumulation, and rendering interpolation. This is reading plus implementation practice, rather than an interactive lesson. Pair it with `SimulationClock` and `RoomPreview.presentation_position`: draw the two simulation snapshots and slide a presentation marker between them while keeping the update step fixed. Do not confuse interpolation between states with repeatedly easing the current position toward a target.

Suggested progression: vector/displacement diagrams → camera transforms → interpolation → shaping curves → ray/segment geometry. The existing algebra background can support the symbolic derivations throughout; arithmetic fluency is not a prerequisite for these exercises. The current lesson's exclusion of matrix algebra applies to that first lesson, not to a permanent limit on future study.

## Wisdom (Communities)

- [DragonRuby Game Toolkit Discord](http://discord.dragonruby.org).
  Official community, linked by the installed SDK's `docs/index.md`; the user is already a member. Use for comparing practical camera policies after understanding the local reproduction. No new account connection, message, or server-history access is implied by listing it.

## Gaps

- No official DragonRuby convention was established for this exact combination of fractional scenery composition and independently aligned direct actors.
- Learning mastery is not yet demonstrated. Lesson exercises provide practice; create learning records only after the user supplies evidence of understanding.
