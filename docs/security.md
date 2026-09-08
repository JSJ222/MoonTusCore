# Security and resource limits

MoonTusCore treats every request value as untrusted.

- Header count and wire bytes are bounded before protocol parsing.
- Field names must be HTTP tokens; CR, LF, NUL, and controls are rejected.
- Decimal values reject signs, alternate bases, and signed 64-bit overflow.
- Paths and generated identifiers exclude separators and query fragments.
- Metadata limits cover wire bytes, entry count, and decoded bytes.
- PATCH body length must fit per-request and total upload limits.
- State is validated before mutation and compare-and-swap blocks stale writes.

Application adapters must still provide authentication, authorization, tenant
quotas, rate limits, TLS, CSRF/CORS policy where relevant, durable cleanup,
malware scanning, and safe post-processing. The in-memory store retains complete
bytes and is unsuitable for untrusted production traffic.

Default limits are examples, not a deployment policy. Operators should choose
values based on memory, storage, reverse-proxy, and timeout budgets.
