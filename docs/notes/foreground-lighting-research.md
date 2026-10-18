# Lighting tall foreground scenery in an angled 2D view

Historical geometry note (2026-10-19): [ADR-0015](../adr/0015-use-colliders-for-foreground-fading.md) removes all alpha-derived fade geometry, SpriteGeometry, generated occluder assets, and their tasks/dependencies. Fading uses active wall/door colliders plus full artwork rectangles; lighting uses active object colliders under ADR-0014. Pipeline instructions, silhouette-specific behavior, and measurements below describe earlier implementations. Current setup is in [README](../../README.md), and current behavior is in [CONTEXT](../../CONTEXT.md).

Date: 2026-10-19. Status: research leading to the accepted collider-base approximation in [ADR-0014](../adr/0014-use-collider-bases-for-lighting.md). The historical problem and alternatives below record the investigation; the prototype is now folded into normal RoomPreview.

## What the original raycaster assumed

`Room#light_blockers` obtains `SpriteGeometry.edges` from every selected non-floor sprite, including caps. Those edges describe the projected artwork. The raycaster correctly answers visibility within that flat arrangement, but the arrangement does not describe a wall standing on a floor. A sprite's upper pixels can cover floor coordinates without occupying that floor space. See the [integrated checkpoint](raycast-lighting.md#collider-bases-and-integrated-lighting) for the replacement policy.

Use the existing [glossary](../../GLOSSARY.md#rendering) distinction between foreground fading and movement/lighting selection. [ADR-0012](../adr/0012-continuous-occluder-queries.md) establishes available visual silhouettes; it does not establish their suitability as physical lighting geometry. The fade unit's current `footprint` is a base-sprite rectangle, not an independently authored physical footprint.

## Separate the caster from the picture and the receiver

A shadow **caster** describes what stops illumination. A **receiver** describes the surface whose appearance is shaded. These are independent authoring choices: Unity's 2D shadow component supports sprite, collider, or manually edited casting shapes, separates casting onto others from self-shadowing, and selects receiving sorting layers. These are documented engine capabilities, not evidence that every angled-view game uses one particular geometry policy. [Unity component reference](https://docs.unity.com/en-us/engine/6000.3/manual/unity2d/2d-urp/2d-index/2d-shadows/shadow-caster2d).

Godot likewise provides independently authored occluder polygons and separate controls for which objects receive a light and which objects cast its shadows. A mask is a membership rule; it does not add physical elevation to a flat shadow computation. [Godot 2D lighting documentation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html).

For our proposed floor-lighting approximation, give a tall wall a simple blocking shape at its physical base and retain its full artwork for foreground fading. Think of moving pieces on a floor plan while keeping their upright illustrations separate. The light's planar origin must use that same floor plane. A wall can block floor illumination while its visible face still receives light. Simply multiplying the floor's lightmap over the entire finished scene would mix those two receiving surfaces again. This is a project recommendation, not a demonstrated universal convention.

## Documented ways to shade the upright artwork

One concrete open-source **experiment**, `lighting-2d`, distinguishes ground receivers and wall receivers. It computes ground shadows separately, shades wall faces using the light's relationship to their bottom edges, and projects shadows onto walls where ground shadows cross those bottom edges. Separate masks combine the results. It omits an overlapping caster's own shadow on the corresponding receiver and uses two wall layers to handle some overlaps; its author explicitly notes that more complex overlaps exceed that arrangement. This demonstrates a deliberate 2.5D approximation, not a general depth solution or evidence from a shipped game. [Implementation and explanation](https://github.com/basementuniverse/lighting-2d#how-it-works).

For a smaller prototype, a wall face could receive a single light value sampled at a suitable base point, optionally restricted by which side faces the light. This sacrifices detailed shadows across the face. Caps could initially receive ambient illumination only. These are proposed artistic shortcuts to evaluate, rather than established project decisions. Ignoring a lamp's own mounted host is a different rule from preventing that host from receiving its own cast shadow; preserve the distinction.

## More geometry buys more physical consistency

Brigador provides a documented shipped-game example of richer data. Stellar Jockeys describes exporting per-pixel camera depth with its sprites and using sun-angle-dependent slices of that depth to approximate cast shadows. Low sun angles expose stair-step artifacts. The newsletter's additional reverse-depth image is a proposed improvement for Brigador Killers, not a feature established as shipped. This is a sunlight system, not a drop-in implementation for our point lights. [Developer explanation, pages 1–2](https://stellarjockeys.com/wp-content/uploads/2021/12/November-2021-archive.pdf).

A height-aware alternative for our game would assign blockers and light origins heights, then test visibility to a receiver at its own height. A ray can pass above a short obstacle; a wall face can receive illumination while the floor behind it remains shadowed. One planar nearest-hit polygon cannot encode all such answers. Height fields or simple 3D proxy volumes would require additional authored data and different shadow calculations; this is a possible future model, not the next implementation step.

Normal maps supply surface directions for local shading. They do not by themselves provide object volumes or determine whether another object blocks the light. Godot explicitly states that its 2D light height affects normal-mapped shading, not shadow appearance. [Godot normal maps and light height](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html).

## Smallest useful experiment

Keep the existing ray-intersection math. Prototype one wall, its cap, one light, and floor on both sides. Author one ground-plane blocker independently of artwork; draw its polygon light only onto the floor. Shade the face separately with a simple explicit rule, and leave the cap ambient initially. Move the light around both sides and behind the artwork. Check shadow origin, face illumination, cap readability, and foreground fading before choosing room-wide authoring rules. Keep [HD disabled](../adr/0013-keep-hd-disabled.md). No GPU redesign, height-texture pipeline, or new dependency is needed to test this model.
