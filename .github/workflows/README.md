# GitHub Actions

- **CI** (`ci.yml`): Runs on every push/PR to `main`. Builds dashboard + lint.  
  **Spam pushes:** Concurrency is set so only the latest run for the branch is kept; in-progress runs are cancelled. Pushing a lot is fine.

- **Release** (`release.yml`): Runs when you push a tag `v*` (e.g. `v1.0.0`).  
  - **build-portmaster** (Ubuntu): Runs `client/build/portmaster/build.sh`, zips the handheld package and standalone `.love`, uploads as artifacts.  
  - **build-macos** (macOS): Runs `client/build/macos/build.sh`, zips the `.app`, uploads as artifact.  
  - **build-linux** (Ubuntu): Runs `client/build/linux/build.sh`, bundles the LÖVE runtime, uploads as artifact.  
  - **build-windows** (Ubuntu): Runs `client/build/windows/build.sh`, fuses the Windows executable, uploads as artifact.  
  - **release** (Ubuntu): Downloads available artifacts and publishes a GitHub Release attaching `retrosync-portmaster.zip`, `retrosync.love`, `retrosync-macos.zip`, `retrosync-linux.zip`, and `retrosync-windows.zip`.
