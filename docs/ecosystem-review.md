# Ecosystem overlap review

Review date: 2026-09-08.

The project was checked by searching Mooncakes and public GitHub results for
MoonBit with tus, resumable upload, Tus-Resumable, and Upload-Offset terms. No
published MoonBit package or public MoonBit repository implementing the tus 1.0
server-side state machine was identified in those searches.

Nearby projects such as general MoonBit web frameworks provide HTTP transport,
header, route, and body abstractions. They do not replace MoonTusCore's
protocol-specific offset, deferred-length, metadata, rejection-atomicity, and
storage compare-and-swap decisions. MoonTusCore therefore stays framework
neutral and can be integrated into such frameworks later.

The normative functional reference is the public tus 1.0.0 protocol:
https://github.com/tus/tus-resumable-upload-protocol/blob/main/protocol.md

Search results are time-sensitive. This review must be repeated before public
submission and should compare any newly published tus package at API, extension,
storage, error, and conformance-test level.
