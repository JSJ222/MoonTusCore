# Release procedure

1. Update version and changelog; verify README scope and proposal metrics.
2. Run format, API generation, all-target checks/tests/builds, CLI demos, and
   the library example.
3. Inspect moon package --list and confirm the contest application is excluded
   by .moonignore.
4. Confirm a clean tree, license notices, meaningful history, and CI success.
5. Push the public repository only after owner authorization.
6. Run moon publish --dry-run, inspect the package, then publish.
7. Verify the public Mooncakes page, installation command, tag, and notes.

The GitHub repository has been created. Gitlink mirroring and Mooncakes
publication remain pending.
