---
name: domain-modeling
description: Build and sharpen a project's domain model. Use when discussing codebase terminology, writing or editing a GLOSSARY.md, or recording or editing an ADR.
---

# Domain Modeling

Follow [documentation guidance](../../../docs/agents/domain.md). This skill resolves and records concepts; merely reading the glossary does not require invoking it.

## Resolve terms

- Challenge meanings that conflict with the glossary or use one name for distinct concepts.
- Use concrete game scenarios to test relationships and edge cases.
- Check implementation claims against code and distinguish planned behavior.
- Once a term is agreed, update `GLOSSARY.md` using [GLOSSARY-FORMAT.md](GLOSSARY-FORMAT.md). Create it only when there is a definition to record.

## Record decisions

Use [ADR-FORMAT.md](ADR-FORMAT.md) when a decision qualifies. When revisiting an existing ADR, explain the conflict and new trade-off, then record an agreed replacement and update affected links.
