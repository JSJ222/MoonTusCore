# Architecture

MoonTusCore is a protocol decision library, not an HTTP server. Its boundary is
plain TusRequest and TusResponse values so a MoonBit web framework, FFI binding,
worker runtime, or test harness can use the same behavior.

## Layers

1. headers, numbers, base64, and metadata parse bounded wire values.
2. routing, creation, and append validate protocol semantics.
3. AppendPlan carries an immutable transition to the storage boundary.
4. MemoryStore demonstrates create, snapshot, import, and compare-and-swap.
5. TusEngine assembles OPTIONS/POST/HEAD/PATCH for executable examples.
6. scenario, report, and conformance make behavior reproducible.

The public planner API hides ordering rules such as version checks, singleton
headers, overflow detection, offset matching, deferred-length resolution, and
completion. Adapters do not repeat those decisions.

The reference engine deliberately depends on MemoryStore; the protocol planners
do not. A persistent implementation stores an UploadRecord-equivalent snapshot
and applies a plan with one transaction or conditional write.

Header and metadata parsing is linear in request header bytes. Lookup in the
reference store is O(n) because it optimizes for deterministic examples, not
large deployments. PATCH validation is O(header bytes); its in-memory commit is
O(total stored bytes) because immutable Bytes are copied. Production storage
should append externally and keep state update O(1).
