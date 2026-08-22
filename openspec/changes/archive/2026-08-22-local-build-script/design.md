## Context

See `proposal.md` for motivation and background. The repository contains custom hardware shields (`boards/shields/rolio` and `boards/shields/vista508`), a custom manifest (`config/west.yml`) importing external modules, and a matrix definition file (`build.yaml`).

## Goals / Non-Goals

**Goals:**
- Provide a single executable script `./build.sh` that works seamlessly on macOS / Linux with Docker/OrbStack.
- Reproduce the exact compilation environment and compiler version as GitHub Actions CI.
- Support interactive menu, direct target selection, and a fast pre-push test suite (`--test`).
- Persist Zephyr/ZMK dependencies in a Docker named volume (`rolio-zmk-cache`) for sub-second build initialization on incremental runs.
- Output clean `.uf2` files in `./artifacts/`.

**Non-Goals:**
- Managing flashing to physical hardware over USB (copying the `.uf2` file to the mounted bootloader drive is handled by the user or OS).
- Replacing native Zephyr toolchain development if someone wants IDE-level GDB debugging.

## Decisions

### 1. Script Architecture (Bash + Python Parser)
- **Decision:** Use a Bash wrapper (`./build.sh`) with an inline Python 3 script to parse `build.yaml`.
- **Rationale:** macOS does not ship with `yq` by default, but Python 3 is standard. Using an embedded Python snippet parses YAML safely and outputs JSON/line-delimited records for Bash to consume without requiring external Homebrew dependencies.
- **Alternatives Considered:**
  - *Pure Bash parsing*: Fragile with multi-line YAML and variable fields.
  - *Require `yq`*: Adds an external prerequisite for users.

### 2. Docker Execution & Workspace Mounting
- **Decision:** Mount the repository at `/workspace/src` and use a persistent Docker named volume (`rolio-zmk-cache`) at `/workspace`.
- **Rationale:**
  - `west init -l /workspace/src/config` initializes the workspace inside `/workspace`.
  - `west update` pulls Zephyr and upstream modules into `/workspace/zmk`, `/workspace/zephyr`, etc.
  - Keeping `/workspace` in a named volume keeps file I/O fast on macOS while preserving the checkout between builds.
  - The local repo is mounted read-only or bind-mounted so any edits in `boards/shields/` or `config/` are immediately reflected in the build.
- **Alternatives Considered:**
  - *Binding a host cache folder (`.cache/`)*: Slightly slower disk I/O on macOS Docker Desktop and clutters host directory.

### 3. Pre-Push Verification Scope
- **Decision:** Default `--test` (or `-t`) mode builds the 3 primary combinations:
  1. `zmk-rolio461-nicenano_v2-vista508-left` (left half with display widget)
  2. `zmk-rolio461-nicenano_v2-vista508-right` (right half with display widget)
  3. `zmk-nicenano_v2-settings_reset` (settings reset shield)
- **Rationale:** These 3 targets exercise all custom shield overlays, C display widgets, and base board configurations. Testing them provides high confidence for GitHub CI without waiting for all 10 matrix builds.

### 4. Build Artifact Output
- **Decision:** Copy the generated `.uf2` file out of the container to `./artifacts/<artifact-name>.uf2`.
- **Rationale:** Matches GitHub Actions artifact naming conventions directly and makes flashing easy.

## Risks / Trade-offs

- **[Risk]** First build cold start is slow (~2-3 minutes) while Zephyr repositories are cloned.
  - *Mitigation*: Show clear progress output indicating that initial dependencies are downloading into Docker cache.
- **[Risk]** Upstream dependencies in `config/west.yml` change on remote, but local cache is stale.
  - *Mitigation*: Provide `./build.sh --update` or `./build.sh --clean` flags to force `west update` or wipe the named volume.
- **[Risk]** Docker daemon is not running (e.g. OrbStack not started).
  - *Mitigation*: Check `docker info` at script startup and display a friendly error message.
