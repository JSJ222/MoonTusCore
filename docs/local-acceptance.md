# Local acceptance report

Date: 2026-09-08 (Asia/Shanghai).

This report applies the local, pre-publication checks from osc2026-guide. It
does not claim completion of owner-deferred GitHub, Gitlink, CI service, or
Mooncakes steps.

## Result

- Project identity: independent MoonTusCore Git repository on main, no remote.
- Scope: tus 1.0 Core, Creation, and Creation-Defer-Length.
- MoonBit size: 35 .mbt files, 4995 physical lines, 4363 non-empty non-comment
  effective lines.
- History before this report commit: 23 meaningful commits.
- Proposal: 22 lines, within the guide's 30-line limit.
- License: Apache-2.0; tus MIT protocol attribution is documented.

## Commands passed

~~~text
moon fmt --check
moon info
git diff --exit-code
moon check --target all --deny-warn
moon test --target all --deny-warn
moon build --target all
moon doc
~~~

The test suite contains 92 tests. All 92 pass separately on wasm, wasm-gc, js,
and native, for 368 backend test executions.

Native smoke checks passed for version, capabilities, success, conflict, limits,
deferred JSON output, and the library integration example. The conflict and
limits demonstrations intentionally contain rejected requests and confirm that
stored bytes remain unchanged.

## Publication readiness

moon publish --dry-run completed package construction, archive validation, and a
second moon check on the extracted package. The command then attempted the
Mooncakes publish endpoint and failed before publication; no release was
created.

Final contest acceptance still requires the owner-authorized public push,
successful hosted CI, public repository accessibility, Mooncakes publication,
and verification of the public package page. Re-run the ecosystem overlap
search immediately before submission.
