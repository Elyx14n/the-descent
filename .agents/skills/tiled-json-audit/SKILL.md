---
name: tiled-json-audit
description: "Audit The Descent's Tiled room JSON exports against the current importer and agreed room conventions. Use for pre-integration audits and re-export checks covering paths, layers, classes, door variants, colliders, light/pedestal offsets, and Spawn. Use dragonruby-development for runtime fixes."
---

# Tiled JSON Audit

Audit exported room data before integration or after a Tiled re-export. Produce concrete findings and editing instructions, without wiring up gameplay or rewriting assets during an audit-only request.

## Establish the contract

- Use the export the user names; otherwise inspect `mygame/tiled/ritual_gate.json`. Identify the file actually audited and honor requested exclusions, such as an already-completed collision review.
- Follow [document ownership](../../../docs/agents/domain.md). Read the current [authoring workflow](../../../README.md#author-and-preview-rooms-in-tiled), relevant [Tiled decision](../../../docs/adr/0004-tiled-room-authoring.md), [runtime/preview decision](../../../docs/adr/0005-render-data-and-room-preview.md), and [product](../../../PRODUCT.md) for gameplay requirements.
- Inspect [TiledDeserializer](../../../mygame/app/tiled_deserializer.rb), [Room](../../../mygame/app/room.rb), and rendering/player code where relevant. Code establishes what loads; agreed requirements establish intended behavior. Surface conflicts rather than declaring every parser omission a valid design.
- Read [the audit checklist](references/audit-checklist.md). Verify it against current code/docs rather than enforcing this snapshot forever.
- When available, inspect the matching `.tmj`, tileset authoring sources, and `descent.tiled-project` classes. Distinguish source settings, exported effective properties, and runtime defaults. A project default alone does not prove the importer receives that value.
- Prefer SDK references through `DRAGONRUBY_HOME` for uncertain engine behavior and official Tiled docs for uncertain format semantics. Distinguish Tiled features from this importer's supported subset.

## Inspect the export

Parse JSON and enumerate layers, placed objects, effective classes/properties, tilesets, referenced images, door pairs/caps, lights, pedestals, and Spawn. Merge tile properties with placed-object overrides. Do not stop after the first loading error.

Resolve used GIDs and asset paths, inspect image dimensions, and compute transformed geometry where needed. Identify each finding's layer, object ID or tile cell, tileset-local tile ID, and relevant property/rectangle/point. Do not treat an atlas-wide class or collider omission on an unused tile as an in-room defect.

For collision or drawing concerns, inspect relevant atlas crops or supplied screenshots before inferring solid boundaries from artwork. Trace the actual render group and active collider: missing collision, wrong draw order, transparent margins, and bad wall artwork are different problems. Preserve deliberate offsets and irregular room shapes.

A native check through the actual deserializer can establish loading compatibility when needed. Existing tests may hardcode the Ritual Gate export: passing them does not prove another export loads or that artwork looks correct. Inspect native test summaries, not just exit codes. Use [dragonruby-development](../dragonruby-development/SKILL.md) for runtime diagnosis or test work.

## Report actionable findings

Lead with the outcome, then report only material findings:

- **Loading blockers:** unsupported/malformed data, missing assets, broken references or required door pairs.
- **Authoring/gameplay issues:** data loads but contradicts intended placement, collision, class identity, or gate behavior. Distinguish confirmed defects from suspected geometry.
- **Playtest checks:** visual overlap, reachability, light/art alignment, and motion quality that static JSON cannot establish.

For each issue, name the exact object/tile/property, explain its effect, and give the smallest correction in Tiled: map object properties, tile properties/class, Tile Collision Editor, layer assignment, or export settings. Prefer fixing authoring sources and re-exporting over hand-editing generated JSON. Do not prescribe a new property or unsupported feature as though the importer already consumes it.

End with a short inventory or confirmation of relevant checks, exclusions, and what remains unverified. Keep clean audits short; do not create a large report, diagnostic artifacts, code changes, or new architecture unless requested. Re-read the latest export on "check again"; old counts, IDs, and conclusions are not evidence for the new file.
