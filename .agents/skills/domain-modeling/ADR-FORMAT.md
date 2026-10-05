# ADR format

Use `docs/adr/NNNN-slug.md`; increment the highest existing number.

```markdown
---
status: accepted
date: YYYY-MM-DD
---

# Decision title

Context, decision, and rationale in one to three sentences.
```

Add alternatives, consequences, or sources only when they help a future reader assess the choice.

Record an ADR when the decision involves a real trade-off, would be surprising without context, and would be meaningfully costly to reverse. Routine implementation choices do not need one.

When replacing a decision, mark the earlier ADR as superseded and link to the new record.
