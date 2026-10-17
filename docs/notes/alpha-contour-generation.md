# Build-time alpha contour generation

Research date: 2026-10-17. The initial library investigation below preceded the isolated RGeo prototype recorded at the end. Runtime integration is now implemented in [ADR-0011](../adr/0011-generated-tile-occluders.md); the prototype history below records how it was selected.

The proposed boundary is sensible: a host-Ruby Rake task extracts tile-local geometry from sprite alpha and writes ordinary data for DragonRuby to load. This keeps image processing and third-party geometry libraries outside the game runtime. Existing decisions are [alpha-derived bounds](../adr/0007-alpha-derived-scenery-bounds.md), [occupied spans for fading](../adr/0008-occupied-spans-for-foreground-fading.md), and [shared stateless geometry](../adr/0009-measured-render-preparation.md#5-share-stateless-sprite-geometry--retained-as-a-refactor). Replacing the existing fade representation requires preserving its behavior, not just producing plausible lighting outlines.

## Ruby library candidates

| Candidate | Relevant evidence | Assessment for this project |
| --- | --- | --- |
| [Contrek](https://github.com/runout77/contrek) | Ruby API over a C++17 contour tracer, with an optional Ruby tracing implementation. Returns outer rings and hole rings. | Closest direct fit found, but recent and not demonstrated mature enough to call proven. |
| [RGeo](https://github.com/rgeo/rgeo) with GEOS | Ruby geometry API supporting polygon unions and exterior/interior rings. | More established geometry building block; union occupied pixel squares or horizontal run rectangles at build time. It is not an image-contour extractor. |
| [Potracer](https://github.com/kennyp/potracer) | Ruby bindings for libpotrace, accepting binary arrays. | Poor first choice for exact pixel boundaries: old wrapper and a curve-oriented tracing pipeline. |

### Contrek: strong shape match, dependency and maturity questions

Contrek traces **pixel-cell edges**, rather than interpolating an isoline between pixel centers. Its documented result preserves disconnected regions and holes; 4-connectivity is the default, with 8-connectivity optional. This is a better conceptual match for our exact occupied pixels than assuming standard interpolated marching squares reproduces them. [Tracking model, connectivity, and result format](https://github.com/runout77/contrek/blob/main/README.md#tracking-model)

The generator could supply a binary mask instead of comparing original PNG colors. Contrek's supplied matchers compare entire pixel values, so using “not transparent black” directly would misclassify transparent pixels containing other RGB values. Our alpha threshold should be applied first. [Ruby matcher](https://github.com/runout77/contrek/blob/main/lib/contrek/matchers/value_not_matcher.rb), [native matcher](https://github.com/runout77/contrek/blob/main/ext/cpp_polygon_finder/PolygonFinder/src/polygon/matchers/RGBNotMatcher.cpp)

Its `uniq` and `linear` reducers provide duplicate/straight-run reduction; these are the starting choices to evaluate before shape-changing simplification. Exact correctness still needs checking against fixtures. [Reducer source](https://github.com/runout77/contrek/blob/main/lib/contrek/reducers/linear_reducer.rb)

Live RubyGems metadata reports **1.4.5, released 2026-10-11**. The project became a gem in May 2025 and rewrote its core pixel geometry in July 2026. Active releases and included tests are positive evidence, but do not establish broad adoption or correctness on our assets. Tests include polygon/hole examples and randomized inputs. [RubyGems API](https://rubygems.org/api/v1/gems/contrek.json), [changelog](https://github.com/runout77/contrek/blob/main/CHANGELOG.md), [polygon specs](https://github.com/runout77/contrek/blob/main/spec/finder/polygon_finder_spec.rb), [randomized specs](https://github.com/runout77/contrek/blob/main/spec/finder/polygon_finder_random_spec.rb)

The gem declares Ruby >= 3.0, dependencies on ChunkyPNG, concurrent-ruby, ffi, and Rice 4.5.0, and an automatically built native extension. Its build uses C++17, pthreads, and zlib. **The optional Ruby tracer does not make this a native-dependency-free gem:** the top-level loader still requires the extension. These declarations are not proof of Ruby 3.4 compatibility; that remains untested here. [Gemspec](https://github.com/runout77/contrek/blob/main/contrek.gemspec), [extension build](https://github.com/runout77/contrek/blob/main/ext/cpp_polygon_finder/extconf.rb), [loader](https://github.com/runout77/contrek/blob/main/lib/contrek.rb)

The Ruby code/wrappers are MIT; the C++ core is AGPLv3. It should not be described simply as an MIT gem. This note records the upstream licensing distinction without asserting legal consequences for our proposed asset-generation use. [Upstream licensing](https://github.com/runout77/contrek/blob/main/LICENSE.md)

### RGeo + GEOS: an alternative to marching squares

Union the solid pixel cells, or first combine them into horizontal run rectangles, then extract each resulting polygon's exterior and interior rings. A union eliminates edges internal to the occupied region. This is a proposed use of documented geometry operations, not a tested project pipeline. RGeo's GEOS-backed implementation needs native GEOS; PNG reading and alpha masking remain separate generator responsibilities. [RGeo repository](https://github.com/rgeo/rgeo), [spatial programming introduction](https://github.com/rgeo/rgeo/blob/master/doc/An-Introduction-to-Spatial-Programming-With-RGeo.md)

### Potracer and searches for marching-squares gems

Potracer's latest published release is **1.1.4 from 2014-02-14**. Its native extension needs the libpotrace library and headers. Potrace is intended to trace smooth vector graphics, with curve optimization and speckle suppression; its default speckle threshold is 2. A wrapper around that pipeline is not an obvious simplification for exact, small sprite polygons and straight ray-intersection segments. [Gem release history](https://rubygems.org/gems/potracer), [extension build](https://github.com/kennyp/potracer/blob/master/ext/potracer/extconf.rb), [Potrace documentation](https://potrace.sourceforge.net/)

Targeted RubyGems API searches found no packages for `marching_squares` or `isolines`. The gems `contour` and `contours` are unrelated Rails/configuration packages. A small Ruby/inline-C marching-squares gist exists, but that is not evidence of a maintained, tested gem. These search results are not proof that no suitable Ruby library exists. [Marching-squares search](https://rubygems.org/api/v1/search.json?query=marching_squares), [isolines search](https://rubygems.org/api/v1/search.json?query=isolines), [contour search](https://rubygems.org/api/v1/search.json?query=contour), [author's gist](https://gist.github.com/mieko/df86aa23c21d658a3552)

## Evaluation boundary

A possible small pipeline is `bin/rake assets:occluders`: read the current tileset crops and their variants, decode PNG alpha, classify alpha > 0 as occupied, extract tile-local outer/hole rings, remove only duplicate and collinear vertices, and export deterministic JSON. Include source-image fingerprints and generation settings so stale output can be detected. Keep generated files in the project; DragonRuby loads data and applies sprite transforms without loading the generator's gems. This task name and output contract are proposals, not implemented commands.

If evaluating interpolated marching squares, first convert alpha to a binary mask, then trace a middle level with a transparent border. Standard sample-center interpolation can cut pixel corners; it is not automatically the exact union of pixel cells. Check coordinate placement and diagonal connectivity explicitly. [Marching-squares behavior and limitations](https://scikit-image.org/docs/stable/api/skimage.measure.html#skimage.measure.find_contours)

Fading still needs its occupied-width and actor-center queries adapted and tested against the generated geometry. Lighting can consume ring segments later. Per-tile extraction removes internal decomposition edges within a tile; it does not automatically remove boundaries hidden by adjacent or overlapping room tiles. Room-wide cleanup is a separate future decision. Current pixel scans happen at room load, so moving them into a build task alone does not establish a gameplay frame-time improvement.

The goal is reusable boundary geometry, not a requirement to use the marching-squares algorithm specifically. Compare a small RGeo union prototype with Contrek on representative real tiles before selecting a dependency. Check empty/full masks, one pixel, thin arms, an L shape, holes, disconnected islands, diagonal contact, and pixels touching crop edges. Require repeatable output and preserve original alpha occupancy before considering deliberate simplification.

Avoid adopting streaming, parallel tracing, spatial indexing, or a general geometry framework for this small build task. The initial investigation did not install or evaluate either candidate; the later RGeo prototype is described below.

## RGeo prototype — 2026-10-17

The user approved trying RGeo/GEOS with a coarse exterior rather than exact holes and islands. [`bin/rake assets:occluders`](../../Rakefile) now reads `mygame/tiled/ritual_gate.json` directly. Its four embedded tilesets already contain the atlas paths, cell dimensions, columns, margins, and spacing, so no separate tileset export is needed. Every atlas cell is processed, covering unplaced artwork and door/animation variants without interpreting their gameplay properties. The user's separate `mygame/sprites/doors.json` was not changed or required.

[`OccluderAssets`](../../lib/occluder_assets.rb) unions occupied pixel squares, fills interior holes, and simplifies exteriors with GEOS's topology-preserving simplifier. It removes collinear vertices and normalizes counterclockwise rings to a consistent starting point. Output uses crop-local bottom-left pixel-edge coordinates without a repeated closing point. Transparent RGB values are ignored; alpha > 0 determines occupancy. The first trial kept only the largest connected polygon; preview feedback subsequently required retaining every disconnected component, as recorded below.

Outputs remain experimental under ignored `tmp/occluders/`: JSON with atlas fingerprints and generation settings, plus an HTML artwork/outline overlay. `TOLERANCE=2 OUT=tmp/occluders-2` produces the coarser comparison. The generator does not modify Tiled files, collision, fading, or lighting. No runtime geometry consumer has been implemented.

Initial measurements with the largest-component-only policy, Ruby 3.4.7, RGeo 3.1.0, ChunkyPNG 1.4.0, and GEOS 3.12.1:

| Source-pixel tolerance | Nonempty tiles | Median edges per tile | Maximum edges | Total edges |
| --- | --- | --- | --- | --- |
| 1 | 542 | 10 | 57 | 6,718 |
| 2 | 542 | 6 | 34 | 4,193 |

These counts cover all four atlases, including floor art and unplaced tiles. They are not per-room rendering costs or a measured raycasting/frame-time improvement. One-pixel tolerance is the initial default, not a validated visual choice. Simplification can replace tiny rectangles with triangles or move small corners within tolerance; retaining a major notch does not imply pixel-exact coverage.

The initial six desktop-Ruby tests passed (23 assertions), covering empty/boundary pixels, alpha-vs-RGB occupancy, filled holes/discarded islands, a substantial L-shaped notch, narrow-wall extents, detail reduction/valid polygons, and repeatable real-export generation without map modification. All 150 existing native game tests and RuboCop also passed. A selected wall/door contact sheet was inspected for coordinate alignment; it does not establish gameplay readability or shadow quality. Review both HTML previews before choosing a tolerance or migrating consumers.

GEOS was unavailable system-wide and sudo required a password. Testing used Ubuntu GEOS packages extracted under `/tmp/descent-geos`, with development gems under ignored `tmp/bundle`. Permanent contributor setup is documented in the [README](../../README.md#generate-tile-occluders). No system package installation succeeded.

### Preview correction: retain disconnected wall and cap pieces

The user found sprites with a wall in one corner and a cap in another losing one of those pieces in both tolerance previews. This came from the largest-component selection, before simplification. Coarse detail should not imply dropping separate structural parts.

The generator now retains every connected component and simplifies each exterior independently. It fills internal holes as before, and does not introduce connecting segments between separate polygons. Small detached pixels are retained too; no noise-size threshold has been added. JSON format version 2 replaces the singular `polygon` with a deterministically sorted `polygons` array. The HTML draws every polygon and reports total part and edge counts per tile. Both tolerance previews are regenerated at their existing paths.

Regression coverage includes a wall and smaller detached cap at both tolerances, checking that both remain and the gap stays empty. The export test also checks that every generated polygon appears in the preview.

The regenerated data contains 871 separate polygons across the same 542 nonempty tiles at each tolerance. Counts below sum edges across every component in a tile:

| Source-pixel tolerance | Median edges per nonempty tile | Maximum edges per tile | Total edges |
| --- | --- | --- | --- |
| 1 | 12 | 106 | 7,933 |
| 2 | 7 | 81 | 5,295 |

The higher counts reflect retaining previously omitted artwork. These remain whole-atlas geometry counts, not gameplay timing measurements.

All seven generator tests pass (34 assertions), RuboCop passes, and both regenerated previews contain every exported polygon. A wall/cap contact sheet confirms separate pieces receive separate outlines. Runtime code is unchanged; native game tests were not rerun for this generator-only correction.

### Selected tolerance and development dependencies

The user approved the two-source-pixel preview. The generator and Rake task now default to tolerance 2; tolerance 1 remains available for comparison. This approves the generated outline detail, without establishing runtime fade or lighting behavior.

The prototype added three development gems: RGeo for GEOS geometry operations, ChunkyPNG to decode PNG pixels/alpha and encode the preview artwork, and Minitest for desktop-Ruby generator tests. RGeo does not decode PNG files. Minitest supports verification and is not needed to generate assets; native DragonRuby tests cannot load this host-Ruby GEOS extension. Other gems shown during installation were existing project dependencies installed again into ignored `tmp/bundle`. GEOS itself is a native library, not another gem. None of these additions is loaded by game runtime code.


## Runtime integration and removal of galleries

After approving the outlines, the user requested removal of previews and integration into the game. The generator now writes only `mygame/data/occluders.json`; standalone HTML and image gallery code/files have been removed. Format version 3 includes polygons, bounds, and horizontal regions derived from the simplified polygons, with source fingerprints and atlas/grid metadata. Runtime loading reads this prepared data and rejects outdated sources; it no longer decodes pixel arrays or derives alpha geometry. `SpriteGeometry` transforms the prepared geometry for active sprite variants. See [ADR-0011](../adr/0011-generated-tile-occluders.md) for the accepted semantics and approximation trade-offs, and [README](../../README.md#generate-tile-occluders) for regeneration commands. Earlier prototype measurements and preview paths above are historical.


During integration, a check found 29 prototype tiles with redundant or overlapping contour parts after independent simplification and hole filling. The final generator unions the filled regions and simplifies the complete tile with topology preservation. This removes boundaries within filled areas and preserves separation between exposed components. A new fixture covers an island inside a filled hole plus a genuinely disconnected external piece.

The repeatability test also exposed different simplification choices when GEOS received components in a different traversal order. Input rings and component ordering are now normalized before simplification, in addition to normalizing output. The library processes rings in input traversal order; this makes the caller's ordering significant. [GEOS simplifier source](https://raw.githubusercontent.com/libgeos/geos/3.12.1/src/simplify/TopologyPreservingSimplifier.cpp)

Final checks: eight generation tests pass (38 assertions), all 152 native tests pass, and RuboCop passes. All generated tile geometries are valid, with 867 exposed contours and no redundant component boundaries. Standalone previews are removed; the in-game B overlay remains available for fading diagnostics. Gameplay checks around corners, door states, and fade transitions still require playtesting.
