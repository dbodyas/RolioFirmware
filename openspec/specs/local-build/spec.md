## Purpose

Provides a local Docker-based build tool that replicates the GitHub Actions ZMK compilation environment for reliable local firmware testing and verification.

## Requirements

### Requirement: Local Docker container build execution
The system SHALL provide a CLI script `./build.sh` that mounts the local repository into the official `zmkfirmware/zmk-build-arm:stable` container and executes the Zephyr/West build pipeline.

#### Scenario: Build a single target successfully
- **WHEN** the user executes `./build.sh` with a specific target name or alias (e.g. `./build.sh left` or `./build.sh zmk-rolio461-nicenano_v2-vista508-left`)
- **THEN** the container initializes the West workspace, updates dependencies, compiles the firmware, and outputs the resulting `.uf2` file into `./artifacts/`.

#### Scenario: Missing Docker daemon
- **WHEN** the user runs `./build.sh` while the Docker/OrbStack daemon is not running or unreachable
- **THEN** the script outputs a clear error message indicating that Docker is unavailable and exits with a non-zero code.

### Requirement: Matrix parsing from build.yaml
The system SHALL dynamically parse `build.yaml` to discover board, shield, snippet, and cmake-args matrix combinations without hardcoded configurations.

#### Scenario: Interactive target selection
- **WHEN** the user executes `./build.sh` without any arguments
- **THEN** the script displays an interactive numbered menu of available targets parsed from `build.yaml` allowing the user to select which firmware to compile.

#### Scenario: Direct target matching
- **WHEN** the user executes `./build.sh <target-name>`
- **THEN** the script matches `<target-name>` against `artifact-name` or common aliases (e.g., `left`, `right`, `reset`) and compiles the matched matrix entry.

### Requirement: Pre-push verification test suite
The system SHALL provide a dedicated pre-push verification mode (`./build.sh --test` or `./build.sh -t`) that compiles the key board and shield combinations required to verify build integrity prior to pushing commits.

#### Scenario: Run pre-push verification
- **WHEN** the user runs `./build.sh --test`
- **THEN** the script compiles `zmk-rolio461-nicenano_v2-vista508-left`, `zmk-rolio461-nicenano_v2-vista508-right`, and `zmk-nicenano_v2-settings_reset`, reporting individual pass/fail status for each and returning exit code 0 only if all pass.

### Requirement: Persistent workspace caching
The system SHALL use a Docker named volume (`rolio-zmk-cache`) to persist West modules (`zmk`, `zephyr`, and MickiusMousius patches) between build invocations.

#### Scenario: Fast subsequent builds
- **WHEN** a build is run after the initial workspace initialization
- **THEN** the script reuses the cached modules from the named volume without re-downloading upstream repositories.

#### Scenario: Clean / Reset cache option
- **WHEN** the user executes `./build.sh --clean` or `./build.sh --prune`
- **THEN** the script removes or resets the cached Docker volume and build artifacts.
