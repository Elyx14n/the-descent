# Mission: Read and modify The Descent's renderer confidently

## Why
Understand the camera and rendering code well enough to change it deliberately and explain the resulting visual behavior. The immediate motivation is the game's diagonal camera jitter and occasional player blur, including why a presentation fix belongs in one drawing stage rather than in movement.

## Success looks like
- Identify whether a value is a world position, a logical screen position, a prepared drawing position, or a source-image coordinate.
- Distinguish a coordinate space, a measurement unit, and an image grid without treating every use of “pixel” as the same thing.
- Trace an actor from interpolation through camera conversion to final raster alignment and explain which operations preserve information.
- Predict what camera movement, window resizing, and final drawing alignment should change before editing code.

## Constraints
- Ground examples in the current project implementation and glossary.
- Keep HD disabled and use the current 320 × 180 logical canvas.
- Use short lessons with immediate practice and feedback.
- Prioritize verbal explanations and spatial visualizations; retain symbolic algebra and conceptual challenge without requiring arithmetic-heavy calculation. Let interactive tools perform numeric work.

## Out of scope
For the first lesson: shader programming, matrix algebra, 3D projection, and choosing a replacement rendering architecture. These may be revisited when useful to the mission.
