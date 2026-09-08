# Release procedure

1. Update version and changelog; verify README scope and proposal metrics.
2. Run format, API generation, all-target checks/tests/builds, CLI demos, and
   the library example.
3. Confirm a clean tree, license notices, meaningful history, and CI success.
4. Push the public repository only after owner authorization.
5. Run moon publish --dry-run, inspect the package, then publish.
6. Verify the public Mooncakes page, installation command, tag, and notes.

GitHub/Gitlink push and Mooncakes publication are pending and intentionally not
performed by the current local implementation task.
