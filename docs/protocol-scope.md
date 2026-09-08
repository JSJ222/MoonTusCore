# Protocol scope

Version 0.1 implements tus protocol 1.0.0 Core, Creation, and
Creation-Defer-Length.

## Implemented

- OPTIONS capability discovery.
- X-HTTP-Method-Override interpretation before routing.
- POST creation with exactly one length form.
- Ordered Upload-Metadata with strict padded RFC 4648 values.
- HEAD offset, known/deferred length, and creation metadata reporting.
- PATCH with exact Content-Length, Upload-Offset, and required media type.
- Final length declaration on PATCH for deferred resources.
- Configurable pre-mutation budgets and stable errors.

## Explicit exclusions

Creation-With-Upload, Checksum, Expiration, Termination, Concatenation, download
responses, authentication, CORS, an HTTP listener, client retry scheduling, and
distributed locking are not implemented.

The core rejects conflicting or unsupported behavior and does not advertise
these extensions. Future extensions should add isolated planners and capability
flags without weakening current invariants.
