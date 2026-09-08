# Persistent adapter guide

Translate the incoming framework request without merging duplicate headers.
Run authentication and tenant policy before loading or mutating the upload.

## Creation

1. Call plan_creation.
2. Allocate a URL-safe identifier.
3. Store length, metadata, offset zero, revision zero, and lifecycle atomically.
4. Return 201 with the resource Location.

## PATCH

1. Load a consistent upload snapshot.
2. Call plan_append with request, snapshot, and config.
3. Append bytes and update state only if revision equals expected_revision and
   offset equals old_offset.
4. Increment revision and return the new offset.
5. On a race, return TUS_STORAGE_CONFLICT and revalidate before any retry.

Filesystems can stage a chunk and lock a small metadata file. SQL adapters can
use a conditional transaction. Object stores can use conditional ETags plus a
manifest, but must handle append semantics and failed multipart cleanup.

Never expose internal paths, database errors, credentials, or tenant identity
through TusError messages.
