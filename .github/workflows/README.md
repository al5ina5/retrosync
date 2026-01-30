# GitHub Actions

- **CI** (`ci.yml`): Runs on every push/PR to `main`. Builds dashboard + lint.  
  **Spam pushes:** Concurrency is set so only the latest run for the branch is kept; in-progress runs are cancelled. Pushing a lot is fine.

- **Release** (`release.yml`): Runs when you push a tag `v*` (e.g. `v1.0.0`).  
  - **build-portmaster** (Ubuntu): Runs `client/build/portmaster/build.sh`, zips the package and a standalone `.love` for desktop Linux/Windows, uploads as artifacts.  
  - **build-macos** (macOS): Runs `client/build/macos/build.sh`, zips the `.app` and `.love`, uploads as artifact.  
  - **release** (Ubuntu): Builds dashboard, downloads the client artifacts, creates a GitHub Release with auto-generated notes and attaches: `retrosync-portmaster-<tag>.zip`, `retrosync-<tag>.love`, `retrosync-macos-<tag>.zip`.
