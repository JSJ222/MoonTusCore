# Domain context

MoonTusCore owns protocol validation and atomic upload-state transitions. It
does not own sockets, authentication, routing, persistent storage selection,
or post-upload processing.

An upload resource has an identifier, an offset, either a known length or a
deferred length, immutable metadata, and a lifecycle state. A successful PATCH
appends exactly at the current offset. A stale offset never changes storage.

