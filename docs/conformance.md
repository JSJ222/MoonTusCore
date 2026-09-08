# Conformance strategy

core_conformance_vectors supplies executable cases for capability discovery,
known creation, missing lengths, HEAD, successful PATCH, stale offsets, media
types, deferred length declaration, and version mismatch.

Each vector checks the response and post-request storage. Rejection vectors
assert that bytes and offsets remain unchanged. The suite complements focused
tests for Base64 tails, overflow, duplicate headers, metadata budgets, lifecycle
invariants, and compare-and-swap replay.

~~~bash
moon test --target all --deny-warn
~~~

These vectors test the declared v0.1 scope. They do not claim every optional tus
extension or replace cross-implementation HTTP testing after an adapter exists.
