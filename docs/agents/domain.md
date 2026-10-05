# Documentation guide

| Document | Owns |
| --- | --- |
| [GLOSSARY.md](../../GLOSSARY.md) | Game terms and meanings |
| [PRODUCT.md](../../PRODUCT.md) | Intended experience and MVP scope |
| [CONTEXT.md](../../CONTEXT.md) | Current status, proposed models, and open questions |
| [docs/adr/](../adr/) | Accepted technical decisions and rationale |
| [docs/notes/](../notes/) | Research evidence and future options |
| [README.md](../../README.md) | Contributor setup, commands, and navigation |
| [AGENTS.md](../../AGENTS.md) | Repository ownership and working conventions |

## Use and maintenance

- Read the glossary for game terminology, the product and context for relevant scope and status, and ADRs touching the system being changed. Consult research only when relevant.
- Inspect `mygame/` to establish implemented behavior. Plans, definitions, and research proposals do not establish implementation or authorize new scope.
- Link to definitions and decisions instead of copying them. Keep the glossary to game concepts; put general programming or SDK explanations in skill references or research.
- Use `domain-modeling` to resolve ambiguous terms and record durable decisions. Create documents when there is something concrete to record.
- Surface conflicts with an ADR and explain why it should be revisited. When a replacement is agreed, record it and update affected links and status. Existing ADRs do not add approval requirements to already authorized work.
