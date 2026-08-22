## Why

Compiling and testing ZMK firmware configurations currently relies on GitHub Actions CI (`build-user-config.yml`), which requires pushing commits to remote to discover compilation errors, shield configuration bugs, or layout issues. A local build runner replicating the exact CI container environment enables instant feedback, offline building, and targeted pre-push verification.

## What Changes

- Introduce a smart local build script (`./build.sh`) powered by Docker and the official `zmkfirmware/zmk-build-arm:stable` container.
- Utilize a Docker named volume (`rolio-zmk-cache`) for caching Zephyr and West dependencies, drastically reducing build times after initial initialization.
- Parse `build.yaml` to dynamically discover all defined board and shield targets.
- Provide flexible target selection:
  - Interactive selection menu if run without arguments.
  - Named target shorthand (e.g. `./build.sh left`, `./build.sh right`, `./build.sh reset`, or exact artifact name).
  - Pre-push verification mode (`./build.sh --test` or `./build.sh --all`) to build key target combinations (`zmk-rolio461-nicenano_v2-vista508-left`, `zmk-rolio461-nicenano_v2-vista508-right`, `zmk-nicenano_v2-settings_reset`) before pushing to GitHub.
- Automatically copy built `.uf2` firmware files to a local `./artifacts/` directory with clean naming matching GitHub Actions CI artifacts.
- Update `.gitignore` to exclude local build artifacts and ephemeral directories.

## Capabilities

### New Capabilities
- `local-build`: Provides CLI and Docker-based local build orchestration for ZMK keyboard firmware matching the remote GitHub Actions environment.

### Modified Capabilities
*(None)*

## Impact

- **New files**: `build.sh`
- **Modified files**: `.gitignore` (ignoring `./artifacts/` and `.build/`)
- **Dependencies**: Docker (or OrbStack) on host machine
- **No breaking changes** to existing GitHub workflows or repository structure.
