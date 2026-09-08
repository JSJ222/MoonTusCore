# ADR 0001: Plan before storage commit

Status: accepted for v0.1.

MoonTusCore separates request validation from mutation. plan_append accepts a
request and immutable snapshot; it returns an AppendPlan containing offsets,
expected revision, resolved length, body, and completion state.

Letting each storage adapter parse headers while appending would duplicate rules
and make partial mutation likely. A plan gives adapters one conditional-write
contract and lets tests prove rejection atomicity.

The cost is that an adapter must load a snapshot before committing and re-run
planning after a race. This is acceptable because tus already requires offset
coordination, and silent automatic retry would be incorrect.
