---
name: design-review
description: Stress-test gameplay features, technical designs, refactors, and performance plans for this DragonRuby game before implementation. Use when behavior, scope, state, or architecture needs agreement; use dragonruby-development for an already-defined implementation or diagnosis.
---

# Design Review

Improve the design enough to identify the smallest useful implementation or prototype. Favor KISS, YAGNI, and a playable vertical slice over speculative architecture.

## Establish the facts

Before asking questions:

1. Read `AGENTS.md`, `PRODUCT.md`, and `CONTEXT.md`.
2. Inspect relevant files under `mygame/`, including tests when present.
3. Resolve `DRAGONRUBY_HOME` using `AGENTS.md`, then consult only the relevant SDK documentation under `$DRAGONRUBY_HOME/docs/` or examples under `$DRAGONRUBY_HOME/samples/`.
4. Distinguish implemented behavior from planned behavior. `PRODUCT.md` and `CONTEXT.md` do not prove that a system exists.

Answer questions from the repository when possible. Ask the user only about choices that materially change player behavior, scope, or the next implementation slice.

## Classify the work

- **Gameplay feature:** clarify player-visible behavior, feedback, success and failure, and the smallest playable version.
- **Bug:** reproduce and establish intended behavior before proposing a design change.
- **Refactor:** name the behavior and useful test seams that must remain stable.
- **Performance:** measure first or identify a credible per-frame scaling risk; do not optimize from intuition alone.
- **Architecture/tooling:** require a current need and compare it with the simplest local alternative.

## Challenge scope and abstractions

Look for unclear requirements, contradictions, missing feedback, edge cases, and simpler designs.

- Build one concrete mechanic before creating a framework for a category of mechanics.
- Prefer ordinary Ruby, DragonRuby primitives, and small explicit data structures.
- Extract boundaries when they improve comprehension, testing, tuning, or reuse already demonstrated by the code.
- Do not introduce an ECS, event bus, dependency-injection system, scene framework, generalized component model, behavior-tree library, or data DSL without concrete pressure that the simpler design cannot handle.
- Do not design for deferred features such as co-op, procedural maps, multiple enemies, modding, or large content pipelines unless the user explicitly brings them into scope.
- Treat new dependencies and edits to bundled SDK files as exceptional choices requiring clear justification.

If a simpler solution meets the current requirement, recommend it and state what is intentionally deferred.

## Stress-test game behavior

Use only scenarios relevant to the change:

- happy path, failure, invalid input, and restart
- frame-to-frame state transitions and timing boundaries
- simultaneous, held, pressed, and released inputs
- collision, geometry, camera, and screen-edge boundaries
- reset, hot reload, and replay behavior
- randomness, seeds, and reproducibility
- save compatibility when persistence changes
- asset dimensions, anchors, transparency, and animation boundaries
- player feedback, fairness, readability, and debug observability
- per-frame work and allocations when scale makes them credible risks

Separate facts that can be tested automatically from experiential questions that require playtesting.

## Prefer learning prototypes

Do not demand abstract certainty about game feel, timing, tension, control response, or readability. For experiential uncertainty, propose the smallest instrumented prototype or playtest that can answer the question. Define what to observe and what decision the result will inform.

## Preserve repository terminology

Use `PRODUCT.md` for intended player experience and MVP scope. Use `CONTEXT.md` for current status, accepted decisions, open questions, and stable domain terminology. Do not force either document into a different role.

Call out contradictions between the request, documents, and implementation. Recommend a canonical term when ambiguity would affect the design.

Suggest documentation updates only for durable decisions. Do not turn temporary implementation detail or exploratory ideas into project policy.

## Finish

Do not implement during a design-only request. Once decisions that materially affect the next slice are resolved, summarize:

- agreed player-visible behavior
- smallest valuable slice or learning prototype
- important state and data
- observability and testable invariants
- remaining experiential questions and playtest needs
- risks and explicitly deferred ideas
- a small, incremental implementation plan

Wait for confirmation before implementation unless the user already requested both design and implementation.
