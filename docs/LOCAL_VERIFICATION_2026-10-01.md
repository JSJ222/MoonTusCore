# Local verification — 2026-10-01

This records the v0.1.1 release verification. The change is available in the
public GitHub repository and on mooncakes.io.

- Toolchain: `moonc 0.10.14+7d59c7ec9`, `moon 0.1.20260920`.
- Change: Checked outbound metadata serialization canonicalizes values and enforces key, count, and wire budgets.
- `moon fmt --check`, all-target strict check, and all-target strict build: passed.
- All-target tests: 93 passed per listed backend; zero failed.
- Native runnable example: `moon run examples/library-demo --target native` passed.
- Effective local MoonBit lines: 4467, counting nonblank, non-`//` lines in
  checked-in `.mbt` files including tests and examples, excluding generated
  build artifacts and downloaded dependencies.
- License: Apache-2.0; existing README, CI workflow, examples, and tests remain
  part of the repository.
- GitHub `main`: every commit has `JSJ222` as author and committer; the
  rewritten history preserves the project file tree.
- GitHub Actions: [CI run 36823909581](https://github.com/JSJ222/MoonTusCore/actions/runs/36823909581)
  passed after the history update.
- Mooncakes: `JSJ222/tus-core` version `0.1.1` was published successfully and
  confirmed by a registry search.

For moonc 0.10.14, strict check/build/test use
`--deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package`. The warning list exempts only the compiler's
`implicit_impl_as_method` and `test_unqualified_package` migration warnings;
all other warnings remain fatal. Migrating those call sites and derived-method
exposure is future maintenance, not a completed fix.

Reproduction from the repository root:

```sh
moon fmt --check
moon check --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon build --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon test --target all --deny-warn --warn-list=-implicit_impl_as_method-test_unqualified_package
moon run examples/library-demo --target native
```

The published package remains subject to the documented protocol scope and
security limits; passing these checks does not imply support for unimplemented
tus extensions or a production-ready HTTP server.
