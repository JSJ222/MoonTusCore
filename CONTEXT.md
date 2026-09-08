# Domain context

MoonTusCore owns protocol validation and atomic upload-state transitions. It
does not own sockets, authentication, routing middleware, persistent storage
selection, quotas across users, malware scanning, or post-upload processing.

An upload resource has a safe identifier, committed offset, known or deferred
length, immutable metadata, monotonic revision, lifecycle, and stored bytes.
The authoritative invariant is stored bytes equals Upload-Offset and does not
exceed Upload-Length when the length is known. A complete resource has equal
offset and length.

A PATCH transition has two phases:

1. plan_append validates request and snapshot without mutation.
2. Storage commits the AppendPlan only when revision and old offset still match.

A stale plan is a storage conflict and changes no bytes. This split is the
storage-neutral seam used by database, file, or object-store adapters.
