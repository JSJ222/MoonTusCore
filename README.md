# MoonTusCore

MoonTusCore is an original MoonBit implementation of the decision layer for
[tus 1.0](https://tus.io/protocols/resumable-upload). It validates HTTP-shaped
values and turns them into bounded, atomic upload-state transitions without
owning sockets, a web framework, authentication, or a persistence technology.

Version 0.1 implements Core, Creation and Creation-Defer-Length. It includes a
compare-and-swap storage contract, an in-memory reference store, deterministic
scenario reports, executable conformance vectors, a Native CLI, and a library
example.

## Why a protocol core?

Resumable upload bugs usually live between the HTTP adapter and storage:
duplicate headers get collapsed, stale offsets overwrite bytes, deferred
lengths become inconsistent, or a rejected request mutates state. MoonTusCore
makes those decisions explicit and testable. Framework adapters translate a
request into TusRequest; storage adapters commit only a validated AppendPlan.

## Features

- Strict Tus-Resumable 1.0.0 negotiation and duplicate-preserving headers.
- Core X-HTTP-Method-Override interpretation before request routing.
- OPTIONS, collection POST, resource HEAD, and offset-checked PATCH.
- Known and deferred upload lengths with overflow-safe integer parsing.
- Strict RFC 4648 decoding for ordered, duplicate-free Upload-Metadata.
- HEAD reporting of offset, length/deferred state, and creation metadata.
- Configurable upload, patch, header, path, and metadata resource budgets.
- Revision plus offset compare-and-swap semantics; rejection never mutates.
- Structured stable error codes and protocol decision traces.
- Text/JSON scenario reports and ten built-in conformance vectors.
- No runtime dependencies in the published library.

## Install

After publication:

~~~bash
moon add JSJ222/tus-core
~~~

The source repository is public at
https://github.com/JSJ222/MoonTusCore. The Mooncakes release remains pending.

## Quick start

~~~moonbit
let engine = @tus.TusEngine::new().unwrap()
let create = @tus.request(
  "POST",
  "/files",
  headers=@tus.Headers::empty()
    .add("Tus-Resumable", "1.0.0")
    .add("Upload-Length", "5"),
)
let created = engine.handle(create)
let location = created.headers.first("location").unwrap()
let patch = @tus.request(
  "PATCH",
  location,
  headers=@tus.Headers::empty()
    .add("Tus-Resumable", "1.0.0")
    .add("Upload-Offset", "0")
    .add("Content-Type", "application/offset+octet-stream")
    .add("Content-Length", "5"),
  body=b"hello",
)
let uploaded = engine.handle(patch)
assert_eq!(uploaded.status, 204)
~~~

The in-memory TusEngine is a runnable reference. A persistent adapter uses
plan_creation, plan_append, validate_record, and AppendPlan to preserve the same
validation-before-mutation and compare-and-swap rules.

## Run

~~~bash
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target all
moon run cmd/moontus --target native -- demo success
moon run cmd/moontus --target native -- demo deferred --json
moon run examples/library-demo --target native
~~~

The conflict and limits demos intentionally include a rejected request but exit
successfully after showing that the stored bytes remain correct.

## Response model

TusResponse contains the recommended HTTP status, ordered response headers, an
optional stable TusError, and decision traces naming the protocol section.
Adapters remain responsible for writing HTTP responses and enforcing
authentication or application policy before calling the core.

## Supported scope

| Capability | v0.1 |
| --- | --- |
| tus Core 1.0 | Yes |
| Creation | Yes |
| Creation-Defer-Length | Yes |
| In-memory reference storage | Yes |
| Persistent storage contract | Documented planners/CAS seam |
| Creation-With-Upload | No |
| Checksum, Expiration, Termination | No |
| Concatenation | No |
| HTTP server/client | No |

Unsupported extensions are excluded deliberately rather than silently
approximated. See [protocol scope](docs/protocol-scope.md).

## Architecture and safety

- [Architecture](docs/architecture.md)
- [Persistent adapter guide](docs/adapter-guide.md)
- [Protocol scope](docs/protocol-scope.md)
- [Security and resource limits](docs/security.md)
- [Conformance strategy](docs/conformance.md)
- [Release procedure](docs/releasing.md)
- [Domain context](CONTEXT.md)

## Project status

The v0.1 implementation is buildable and tested, and its GitHub repository is
public. Gitlink mirroring and Mooncakes publication remain pending.

## License

Apache-2.0. Protocol attribution and dependency status are recorded in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
