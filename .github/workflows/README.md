# GitHub Actions

- **CI** (`ci.yml`): Runs on every push/PR to `main`. Builds dashboard + lint.  
  **Spam pushes:** Concurrency is set so only the latest run for the branch is kept; in-progress runs are cancelled. Pushing a lot is fine.

- **Release** (`release.yml`): Runs when you push a tag `v*` (e.g. `v1.0.0`). Builds dashboard (and client if `client/build/portmaster/build.sh` exists), then creates a GitHub Release with auto-generated notes.  
  To add build artifacts to the release later, add a step that produces files and pass them to `action-gh-release` via the `files` input.
